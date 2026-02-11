import SwiftUI

struct NodeCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GlassCard(title: "Node", icon: "🖥") {
            HStack(spacing: 10) {
                // Node icon
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.tileFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.tileBorder, lineWidth: 0.5)
                    )
                    .overlay(Text("🍎").font(.system(size: 18)))
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.nodeDisplayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("M4 · \(appState.nodeInfo.ip)")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                Circle()
                    .fill(appState.isConnected ? Theme.onlineGreen : Theme.errorRed)
                    .frame(width: 7, height: 7)
                    .shadow(color: (appState.isConnected ? Theme.onlineGreen : Theme.errorRed).opacity(0.5), radius: 3)
            }

            HStack(spacing: 16) {
                nodeDetail("OS", "macOS \(appState.nodeInfo.osVersion)")
                nodeDetail("Mode", "Local")
            }
            .padding(.top, 4)
        }
    }

    private func nodeDetail(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(Theme.mono(10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
