import SwiftUI

struct QuickActionsCard: View {
    @EnvironmentObject private var appState: AppState

    @State private var promptAction: PromptAction?
    @State private var promptText = ""
    @State private var isRestartConfirmPresented = false

    private enum PromptAction: String, Identifiable {
        case searchMemory = "Search Memory"
        case webSearch = "Web Search"
        case spawnSubAgent = "Spawn Sub-Agent"

        var id: String { rawValue }

        func placeholder(agentName: String) -> String {
            switch self {
            case .searchMemory:
                return "What should \(agentName) search memory for?"
            case .webSearch:
                return "What should \(agentName) search on the web?"
            case .spawnSubAgent:
                return "What should the sub-agent do?"
            }
        }
    }

    var body: some View {
        GlassCard(title: "Quick Actions", icon: "⚡") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    quickButton("Search Memory", icon: "memorychip") {
                        promptAction = .searchMemory
                        promptText = ""
                    }
                    quickButton("Web Search", icon: "magnifyingglass") {
                        promptAction = .webSearch
                        promptText = ""
                    }
                }

                HStack(spacing: 8) {
                    quickButton("List Cron Jobs", icon: "clock.badge") {
                        Task { await appState.quickActionListCronJobs() }
                    }
                    quickButton("Gateway Status", icon: "wave.3.right") {
                        Task { await appState.quickActionGatewayStatus() }
                    }
                }

                HStack(spacing: 8) {
                    quickButton("Ping Node", icon: "dot.radiowaves.left.and.right") {
                        Task { await appState.quickActionPingNode() }
                    }
                    quickButton("Spawn Sub-Agent", icon: "person.2.wave.2") {
                        promptAction = .spawnSubAgent
                        promptText = ""
                    }
                }

                HStack {
                    quickButton("Gateway Restart", icon: "arrow.triangle.2.circlepath.circle") {
                        isRestartConfirmPresented = true
                    }
                }

                // Only show output when there's something real
                if !appState.quickActionOutput.isEmpty && appState.quickActionOutput != "No quick action run yet." {
                    Divider().overlay(Theme.glassStroke)

                    ScrollView {
                        Text(appState.quickActionOutput)
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Theme.tileBorder, lineWidth: 0.5)
                            )
                    )
                }
            }
        }
        .sheet(item: $promptAction) { action in
            PromptSheet(
                title: action.rawValue,
                placeholder: action.placeholder(agentName: appState.agentIdentity.name),
                text: $promptText,
                onSubmit: {
                    let value = promptText
                    promptAction = nil
                    promptText = ""

                    Task {
                        switch action {
                        case .searchMemory:
                            await appState.quickActionSearchMemory(query: value)
                        case .webSearch:
                            await appState.quickActionWebSearch(query: value)
                        case .spawnSubAgent:
                            await appState.quickActionSpawnSubAgent(task: value)
                        }
                    }
                }
            )
        }
        .alert("Restart Gateway?", isPresented: $isRestartConfirmPresented) {
            Button("Restart", role: .destructive) {
                Task { await appState.quickActionGatewayRestart() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will run 'openclaw gateway restart'.")
        }
    }

    private func quickButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.accentYellow.opacity(0.7))
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.innerCardRadius, style: .continuous)
                    .fill(Theme.tileFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.innerCardRadius, style: .continuous)
                            .strokeBorder(Theme.tileBorder, lineWidth: 0.5)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.innerCardRadius))
        }
        .buttonStyle(GlassButtonStyle())
    }
}

private struct PromptSheet: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1 ... 4)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Run") {
                    onSubmit()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
