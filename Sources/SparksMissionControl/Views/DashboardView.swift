import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            // Deep black base
            Theme.baseBackground
                .ignoresSafeArea()

            // Ambient glow orbs
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(Theme.ambientOrbs[0])
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.1)

                    Circle()
                        .fill(Theme.ambientOrbs[1])
                        .frame(width: 350, height: 350)
                        .blur(radius: 90)
                        .position(x: proxy.size.width * 0.85, y: proxy.size.height * 0.2)

                    Circle()
                        .fill(Theme.ambientOrbs[2])
                        .frame(width: 300, height: 300)
                        .blur(radius: 70)
                        .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.85)
                }
                .allowsHitTesting(false)
            }

            VStack(spacing: 14) {
                TitleBarStrip()
                    .padding(.top, 4)

                HStack(alignment: .top, spacing: 16) {
                    // Left column — identity, chat, log
                    VStack(spacing: 14) {
                        IdentityCard()
                        ChatView()
                            .frame(maxHeight: .infinity)
                        ActivityLogCard()
                            .frame(height: 180)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    // Right column — actions & status
                    ScrollView {
                        VStack(spacing: 14) {
                            QuickActionsCard()
                            ServicesCard()
                            CronJobsCard()
                            ModelRoutingCard()
                            NodeCard()
                            SkillsCard()
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(width: 420)
                    .scrollIndicators(.hidden)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Title Bar

private struct TitleBarStrip: View {
    @EnvironmentObject private var appState: AppState

    private var isOnline: Bool {
        appState.connectionState == .connected
    }

    private let shape = RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)

    var body: some View {
        HStack(spacing: 0) {
            // Space for native traffic lights
            Spacer().frame(width: 58)

            // Title
            HStack(spacing: 6) {
                Text(appState.agentIdentity.emoji)
                    .font(.system(size: 16))
                Text(appState.agentIdentity.name.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .tracking(2.5)
                    .foregroundStyle(Theme.accentYellow)
                Text("MISSION CONTROL")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            // Status beacon
            HStack(spacing: 6) {
                Circle()
                    .fill(isOnline ? Theme.onlineGreen : Theme.errorRed)
                    .frame(width: 7, height: 7)
                    .shadow(color: (isOnline ? Theme.onlineGreen : Theme.errorRed).opacity(0.6), radius: 4)

                Text(isOnline ? "ONLINE" : "OFFLINE")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundStyle(isOnline ? Theme.onlineGreen : Theme.errorRed)
            }
            .padding(.trailing, 14)

            // Clock
            Text(appState.estClockText)
                .font(Theme.mono(10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                shape.fill(Color(hex: 0x0A0A0E, alpha: 0.92))
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.03), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                shape.strokeBorder(Theme.glassStroke, lineWidth: 0.5)
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Theme.topHighlight.opacity(0.6), .clear, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
            }
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }
}
