import Foundation
import SwiftUI

struct ChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
        case system
        case tool
    }

    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date, isStreaming: Bool) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}

struct ActivityEntry: Identifiable {
    enum Level {
        case normal
        case success
        case warning
        case error
    }

    let id = UUID()
    let timestamp: Date
    let title: String
    let detail: String
    let level: Level
}

struct CronJob: Identifiable {
    let id = UUID()
    let name: String
    let schedule: String
    let enabled: Bool
}

struct ServicesSnapshot {
    var gateway: String = "Stopped"
    var telegram: String = "Unknown"
    var uptime: TimeInterval?
}

struct NodeSnapshot {
    var host: String = "Unknown"
    var ip: String = "Unknown"
    var osVersion: String = "Unknown"
    var status: String = "Checking"
}

struct CommandResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combined: String {
        let out = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !out.isEmpty && !err.isEmpty {
            return "\(out)\n\n\(err)"
        }
        if !out.isEmpty { return out }
        if !err.isEmpty { return err }
        return "(no output)"
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var agentIdentity: AgentIdentity
    @Published var ownerName: String
    @Published var connectionState: GatewayConnection.ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var activityLog: [ActivityEntry] = []
    @Published var services = ServicesSnapshot()
    @Published var quickActionOutput: String = "No quick action run yet."
    @Published var cronJobs: [CronJob] = []
    @Published var modelRouting: ModelRoutingInfo
    @Published var skills: [String] = []
    @Published var nodeInfo = NodeSnapshot()
    @Published var currentESTTime: Date = Date()

    let config: GatewayConfig

    private let connection: GatewayConnection
    private var clockTask: Task<Void, Never>?
    private var servicesTask: Task<Void, Never>?
    private var cronTask: Task<Void, Never>?
    private var nodeTask: Task<Void, Never>?

    private var connectedSince: Date?
    // HTTP-only — no streaming message tracking needed
    private let estTimeZone = TimeZone(identifier: "America/New_York") ?? .current

    init() {
        let config = GatewayConfig.loadFromDisk()
        let agentIdentity = AgentIdentity.loadFromDisk()
        let ownerName = AgentIdentity.loadOwnerName()
        self.agentIdentity = agentIdentity
        self.ownerName = ownerName
        self.config = config
        self.modelRouting = config.modelRouting
        self.connection = GatewayConnection(
            port: config.port,
            gatewayToken: config.gatewayToken,
            hooksToken: config.hooksToken,
            primaryModel: config.modelRouting.primary
        )

        wireGatewayCallbacks()
        loadSkills()
        startClock()
        startPollingLoops()

        // Clean start — no noise in the log
        connection.connect()

        Task {
            await refreshCronJobs()
            await refreshServicesStatus()
            await refreshNodeInfo()
        }
    }

    deinit {
        clockTask?.cancel()
        servicesTask?.cancel()
        cronTask?.cancel()
        nodeTask?.cancel()
        connection.disconnect()
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    var connectionLabel: String {
        switch connectionState {
        case .connected: return "CONNECTED"
        case .connecting: return "CONNECTING"
        case .checking: return "CHECKING"
        case .disconnected: return "DISCONNECTED"
        }
    }

    var estClockText: String {
        let formatter = DateFormatter()
        formatter.timeZone = estTimeZone
        formatter.dateFormat = "EEE MMM d, h:mm:ss a 'EST'"
        return formatter.string(from: currentESTTime)
    }

    var nodeDisplayName: String {
        let trimmed = config.nodeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Connected Node" : trimmed
    }

    func sendChat(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: trimmed, timestamp: Date(), isStreaming: false))
        addActivity(title: "Chat", detail: "→ \(trimmed)", level: .normal)

        // Show thinking indicator
        let thinkingMsg = ChatMessage(role: .assistant, content: "Thinking...", timestamp: Date(), isStreaming: true)
        messages.append(thinkingMsg)
        let thinkingID = thinkingMsg.id

        Task {
            do {
                let response = try await connection.sendMessage(trimmed)
                // Replace thinking message with real response
                if let idx = messages.firstIndex(where: { $0.id == thinkingID }) {
                    messages[idx] = ChatMessage(id: thinkingID, role: .assistant, content: response, timestamp: Date(), isStreaming: false)
                } else {
                    messages.append(ChatMessage(role: .assistant, content: response, timestamp: Date(), isStreaming: false))
                }
                addActivity(title: "Chat", detail: "← Response received", level: .success)
            } catch {
                // Replace thinking message with error
                if let idx = messages.firstIndex(where: { $0.id == thinkingID }) {
                    messages[idx] = ChatMessage(id: thinkingID, role: .system, content: "Failed: \(error.localizedDescription)", timestamp: Date(), isStreaming: false)
                }
                addActivity(title: "Chat Error", detail: error.localizedDescription, level: .error)
            }
        }
    }

    func quickActionSearchMemory(query: String) async {
        let prompt = "search memory for: \(query)"
        await runAgentQuickAction(label: "Search Memory", prompt: prompt)
    }

    func quickActionWebSearch(query: String) async {
        let prompt = "search the web for: \(query)"
        await runAgentQuickAction(label: "Web Search", prompt: prompt)
    }

    func quickActionPingNode() async {
        await runAgentQuickAction(label: "Ping Node", prompt: "ping the Mac mini node")
    }

    func quickActionSpawnSubAgent(task: String) async {
        let prompt = "spawn a sub-agent to: \(task)"
        await runAgentQuickAction(label: "Spawn Sub-Agent", prompt: prompt)
    }

    func quickActionListCronJobs() async {
        let result = await runOpenClaw(["cron", "list"])
        quickActionOutput = result.combined
        addActivity(
            title: "List Cron Jobs",
            detail: result.exitCode == 0 ? "Loaded cron list via CLI" : "Failed to list cron jobs",
            level: result.exitCode == 0 ? .success : .error
        )
        await refreshCronJobs()
    }

    func quickActionGatewayStatus() async {
        let result = await runOpenClaw(["status"])
        quickActionOutput = result.combined
        addActivity(
            title: "Gateway Status",
            detail: result.exitCode == 0 ? "Fetched gateway status" : "Gateway status command failed",
            level: result.exitCode == 0 ? .success : .error
        )
        await refreshServicesStatus(fromText: result.combined)
    }

    func quickActionGatewayRestart() async {
        let result = await runOpenClaw(["gateway", "restart"])
        quickActionOutput = result.combined
        addActivity(
            title: "Gateway Restart",
            detail: result.exitCode == 0 ? "Gateway restart requested" : "Gateway restart failed",
            level: result.exitCode == 0 ? .warning : .error
        )

        if result.exitCode == 0 {
            connection.connect()
        }
    }

    func refreshCronJobs() async {
        let result = await runOpenClaw(["cron", "list", "--json"])
        guard result.exitCode == 0 else {
            addActivity(title: "Cron Poll", detail: "Failed: \(result.combined)", level: .error)
            return
        }

        guard let data = result.stdout.data(using: .utf8) else {
            addActivity(title: "Cron Poll", detail: "Invalid UTF-8 output from cron list", level: .error)
            return
        }

        let parsed = parseCronJobs(data: data)
        let changed = parsed.count != cronJobs.count
        cronJobs = parsed
        // Only log if count changed — suppress routine polling noise
        if changed {
            addActivity(title: "Cron", detail: "\(parsed.count) jobs loaded", level: .success)
        }
    }

    func triggerCronJob(_ name: String) async {
        let direct = await runOpenClaw(["cron", "run", name])
        if direct.exitCode == 0 {
            quickActionOutput = direct.combined
            addActivity(title: "Cron Trigger", detail: "Triggered \(name) via CLI", level: .success)
            return
        }

        do {
            let response = try await connection.postAgentHook(message: "trigger cron job named \(name)")
            quickActionOutput = response
            addActivity(title: "Cron Trigger", detail: "Triggered \(name) via agent hook", level: .success)
        } catch {
            quickActionOutput = "Failed to trigger \(name): \(error.localizedDescription)"
            addActivity(title: "Cron Trigger", detail: quickActionOutput, level: .error)
        }
    }

    func refreshNodeInfo() async {
        async let hostResult = runCommand("/bin/hostname", [])
        async let ipEn0 = runCommand("/usr/sbin/ipconfig", ["getifaddr", "en0"])
        async let ipEn1 = runCommand("/usr/sbin/ipconfig", ["getifaddr", "en1"])
        async let osVersionResult = runCommand("/usr/bin/sw_vers", ["-productVersion"])

        let host = (await hostResult).combined
        let ip0 = (await ipEn0).combined
        let ip1 = (await ipEn1).combined
        let osVersion = (await osVersionResult).combined

        nodeInfo.host = host
        nodeInfo.ip = ip0 == "(no output)" ? ip1 : ip0
        nodeInfo.osVersion = osVersion
        nodeInfo.status = isConnected ? "Online" : "Gateway disconnected"
    }

    private func wireGatewayCallbacks() {
        connection.onStateChange = { [weak self] state in
            guard let self else { return }
            let previousState = self.connectionState
            self.connectionState = state

            if state == .connected {
                self.connectedSince = self.connectedSince ?? Date()
                self.services.gateway = "Running"
            }
            if state == .disconnected {
                self.services.gateway = "Stopped"
                self.connectedSince = nil
            }

            // Only log meaningful transitions
            if state != previousState {
                switch state {
                case .connected:
                    self.addActivity(title: "Gateway", detail: "Online — port \(self.config.port)", level: .success)
                case .disconnected:
                    self.addActivity(title: "Gateway", detail: "Offline", level: .error)
                case .connecting, .checking:
                    break
                }
            }
        }

        connection.onEvent = { [weak self] event in
            guard let self else { return }
            self.handleGatewayEvent(event)
        }
    }

    private func handleGatewayEvent(_ event: GatewayEvent) {
        switch event {
        case .assistant(let content, _):
            addActivity(title: "Chat", detail: "← \(content.prefix(80))", level: .success)

        case .tool(let name, let status, _):
            addActivity(title: "Tool", detail: "\(name) — \(status)", level: status.lowercased() == "done" ? .success : .warning)

        case .system(let message):
            let lower = message.lowercased()
            let isNoise = lower.contains("gateway is live") && lastState == .connected
            if !isNoise {
                addActivity(title: "System", detail: message, level: .normal)
            }

        case .disconnected(let reason):
            addActivity(title: "Gateway", detail: "Lost connection: \(reason)", level: .error)
        }
    }

    /// Track last state to avoid duplicate log entries
    private var lastState: GatewayConnection.ConnectionState { connection.lastState }

    private func runAgentQuickAction(label: String, prompt: String) async {
        do {
            let response = try await connection.postAgentHook(message: prompt)
            quickActionOutput = response
            addActivity(title: label, detail: "Executed via /hooks/agent", level: .success)
        } catch {
            quickActionOutput = "\(label) failed: \(error.localizedDescription)"
            addActivity(title: label, detail: quickActionOutput, level: .error)
        }
    }

    private func loadSkills() {
        var collected: Set<String> = []
        let manager = FileManager.default
        let roots = [
            NSString(string: "~/.openclaw/skills").expandingTildeInPath,
            NSString(string: "~/.openclaw/clawd/skills").expandingTildeInPath,
            NSString(string: "~/clawd/skills").expandingTildeInPath,
            "/opt/homebrew/lib/node_modules/openclaw/skills",
        ]

        for root in roots {
            let rootURL = URL(fileURLWithPath: root, isDirectory: true)
            guard
                let entries = try? manager.contentsOfDirectory(
                    at: rootURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            for entryURL in entries {
                var isDirectory: ObjCBool = false
                guard manager.fileExists(atPath: entryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }

                let skillFile = entryURL.appendingPathComponent("SKILL.md")
                guard manager.fileExists(atPath: skillFile.path) else { continue }
                collected.insert(entryURL.lastPathComponent)
            }
        }

        skills = collected.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task {
            while !Task.isCancelled {
                currentESTTime = Date()
                if let connectedSince {
                    services.uptime = Date().timeIntervalSince(connectedSince)
                } else {
                    services.uptime = nil
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func startPollingLoops() {
        servicesTask?.cancel()
        servicesTask = Task {
            while !Task.isCancelled {
                await refreshServicesStatus()
                try? await Task.sleep(for: .seconds(30))
            }
        }

        cronTask?.cancel()
        cronTask = Task {
            while !Task.isCancelled {
                await refreshCronJobs()
                try? await Task.sleep(for: .seconds(30))
            }
        }

        nodeTask?.cancel()
        nodeTask = Task {
            while !Task.isCancelled {
                await refreshNodeInfo()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private func refreshServicesStatus(fromText sourceText: String? = nil) async {
        let text: String
        if let sourceText {
            text = sourceText
        } else {
            let result = await runOpenClaw(["status"])
            text = result.combined
        }

        let lower = text.lowercased()
        // Detect Telegram status from `openclaw status` output
        if lower.contains("telegram") {
            if lower.contains("telegram") && (lower.contains("connected") || lower.contains("✅") || lower.contains("running") || lower.contains("enabled") || lower.contains("polling") || lower.contains("active")) {
                services.telegram = "Connected"
            } else if lower.contains("telegram") && (lower.contains("disconnected") || lower.contains("❌") || lower.contains("stopped") || lower.contains("disabled")) {
                services.telegram = "Disconnected"
            } else {
                // If telegram appears in output at all and gateway is running, it's likely connected
                services.telegram = isConnected ? "Connected" : "Unknown"
            }
        } else {
            // If openclaw status doesn't mention telegram but gateway is up, assume connected
            services.telegram = isConnected ? "Connected" : "Offline"
        }

        services.gateway = isConnected ? "Running" : "Stopped"
    }

    private func addActivity(title: String, detail: String, level: ActivityEntry.Level) {
        let entry = ActivityEntry(timestamp: Date(), title: title, detail: detail, level: level)
        activityLog.append(entry)
        if activityLog.count > 100 {
            activityLog.removeFirst(activityLog.count - 100)
        }
    }

    private func parseCronJobs(data: Data) -> [CronJob] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        let jobsArray: [[String: Any]]
        if let array = object as? [[String: Any]] {
            jobsArray = array
        } else if
            let dict = object as? [String: Any],
            let nested = dict["jobs"] as? [[String: Any]] {
            jobsArray = nested
        } else {
            jobsArray = []
        }

        return jobsArray.map { job in
            let name = (job["name"] as? String) ?? (job["id"] as? String) ?? "unnamed"
            let schedule = (job["schedule"] as? String) ?? (job["cron"] as? String) ?? "(unknown schedule)"
            let enabled = (job["enabled"] as? Bool) ?? ((job["status"] as? String)?.lowercased() == "enabled")
            return CronJob(name: name, schedule: schedule, enabled: enabled)
        }
    }

    private func runOpenClaw(_ args: [String]) async -> CommandResult {
        await runCommand("/usr/bin/env", ["openclaw"] + args)
    }

    private func runCommand(_ executable: String, _ arguments: [String]) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = environment

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            process.terminationHandler = { process in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                continuation.resume(returning: CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: CommandResult(exitCode: 1, stdout: "", stderr: error.localizedDescription))
            }
        }
    }
}
