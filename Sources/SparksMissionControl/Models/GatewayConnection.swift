import Foundation

enum GatewayEvent: Sendable {
    case assistant(content: String, streaming: Bool)
    case tool(name: String, status: String, result: String?)
    case system(message: String)
    case disconnected(reason: String)
}

/// Manages communication with the OpenClaw gateway via HTTP only.
/// No fake WebSocket — uses real HTTP health checks + webhook API.
final class GatewayConnection: @unchecked Sendable {
    enum ConnectionState: String, Sendable {
        case disconnected
        case connecting
        case connected
        case checking
    }

    private let port: Int
    private let gatewayToken: String  // For health checks
    private let hooksToken: String    // For /hooks/* API
    private let primaryModel: String
    private let host = "127.0.0.1"
    private let session: URLSession

    private var healthTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "SparksMC.Gateway")
    private(set) var lastState: ConnectionState = .disconnected

    var onStateChange: (@MainActor (ConnectionState) -> Void)?
    var onEvent: (@MainActor (GatewayEvent) -> Void)?

    init(port: Int, gatewayToken: String, hooksToken: String, primaryModel: String, session: URLSession = .shared) {
        self.port = port
        self.gatewayToken = gatewayToken
        self.hooksToken = hooksToken
        self.primaryModel = primaryModel
        self.session = session
    }

    /// Start periodic health checks against the real gateway
    func connect() {
        publishState(.connecting)
        // Check immediately, then every 15 seconds
        Task { await checkHealth() }
        startHealthLoop()
    }

    func disconnect() {
        healthTimer?.cancel()
        healthTimer = nil
        publishState(.disconnected)
    }

    /// Real health check — HTTP GET to gateway
    func checkHealth() async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/") else {
            publishState(.disconnected)
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        if !gatewayToken.isEmpty {
            request.setValue("Bearer \(gatewayToken)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                // Gateway is responding (even 401 means it's running)
                if lastState != .connected {
                    publishState(.connected)
                }
                return true
            } else {
                if lastState != .disconnected {
                    publishState(.disconnected)
                    publishEvent(.disconnected(reason: "Gateway not responding"))
                }
                return false
            }
        } catch {
            if lastState != .disconnected {
                publishState(.disconnected)
                publishEvent(.disconnected(reason: error.localizedDescription))
            }
            return false
        }
    }

    /// Send a message via /v1/chat/completions (synchronous, returns real response)
    func sendMessage(_ message: String) async throws -> String {
        let model = primaryModel.isEmpty ? "claude-opus-4-6" : primaryModel
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": message]
            ]
        ]

        guard let url = URL(string: "http://\(host):\(port)/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !gatewayToken.isEmpty {
            request.setValue("Bearer \(gatewayToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "GatewayConnection", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: "Chat failed: \(body)"])
        }

        // Parse OpenAI-compatible response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let msg = first["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            return String(data: data, encoding: .utf8) ?? "No response"
        }

        return content
    }

    /// Send a wake event
    func postWake(text: String, mode: String = "now") async throws -> String {
        try await postJSON(
            path: "/hooks/wake",
            payload: [
                "text": text,
                "mode": mode,
            ]
        )
    }

    /// Post to agent hook (kept for compatibility)
    func postAgentHook(message: String, sessionKey: String = GatewayConfig.defaultSessionKey, deliver: Bool = false) async throws -> String {
        try await postJSON(
            path: "/hooks/agent",
            payload: [
                "message": message,
                "sessionKey": sessionKey,
                "deliver": deliver,
            ]
        )
    }

    // MARK: - Private

    private func startHealthLoop() {
        healthTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 15, repeating: 15)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.checkHealth() }
        }
        timer.resume()
        healthTimer = timer
    }

    private func publishState(_ state: ConnectionState) {
        lastState = state
        let handler = onStateChange
        Task { @MainActor in
            handler?(state)
        }
    }

    private func publishEvent(_ event: GatewayEvent) {
        let handler = onEvent
        Task { @MainActor in
            handler?(event)
        }
    }

    private func postJSON(path: String, payload: [String: Any]) async throws -> String {
        guard let url = URL(string: "http://\(host):\(port)\(path)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !hooksToken.isEmpty {
            request.setValue("Bearer \(hooksToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 120 // Agent runs can take time

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "GatewayConnection",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]
            )
        }

        return String(data: data, encoding: .utf8) ?? "OK"
    }
}
