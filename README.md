<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Swift-6.2-F05138?style=for-the-badge&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/SwiftUI-Native-007AFF?style=for-the-badge&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/license-MIT-FFD60A?style=for-the-badge" />
</p>

<h1 align="center">🤖 OpenClaw Mission Control</h1>

<p align="center">
  <strong>A native macOS command center for your OpenClaw AI agent.</strong><br/>
  Real-time gateway integration. Live chat. Full operational awareness.<br/>
  Built with SwiftUI. Powered by <a href="https://github.com/openclaw/openclaw">OpenClaw</a>.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-operational-30D158?style=flat-square" />
  <img src="https://img.shields.io/badge/design-dark%20glass-0A0A0A?style=flat-square" />
</p>

---

## What is this?

Mission Control is a **native macOS desktop app** that serves as a real-time dashboard and command interface for your [OpenClaw](https://github.com/openclaw/openclaw) AI agent. Think of it as mission control for your personal AI — monitor services, chat directly with your agent, manage cron jobs, and trigger actions, all from a single glass-dark interface.

This isn't a static dashboard. **Every panel is live. Every button does something real.**

---

## ✨ Features

| Feature | Description |
|---|---|
| **Live Chat** | Full bidirectional chat with your agent via gateway WebSocket. Streaming responses, tool call indicators. |
| **Service Monitoring** | Real-time status of Gateway, Telegram, ElevenLabs, AgentMail — with connection uptime tracking. |
| **Quick Actions** | One-click commands: search memory, web search, list cron jobs, ping nodes, spawn sub-agents, restart gateway. |
| **Cron Management** | View and trigger scheduled jobs directly from the dashboard. |
| **Model Routing** | See your active model, fallback chain, and available aliases at a glance. |
| **Activity Log** | Real-time event stream — messages, tool calls, system events with timestamps. |
| **Node Status** | Monitor your connected node details and availability. |
| **Skills Arsenal** | View all installed agent skills and capabilities. |

---

## 🖥️ Screenshots

<p align="center">
  <em>Dark glass UI with live gateway integration</em>
</p>

![OpenClaw Mission Control](./screenshots/mission-control.png)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│          OpenClaw Mission Control            │
│              (SwiftUI · macOS)               │
├─────────────────────────────────────────────┤
│                                             │
│   WebSocket ←→ OpenClaw Gateway (localhost) │
│   HTTP POST → /hooks/agent, /hooks/wake     │
│   Config   ← ~/.openclaw/openclaw.json      │
│   CLI      ← openclaw status, cron list     │
│                                             │
└─────────────────────────────────────────────┘
```

The app reads your gateway config on launch, establishes a WebSocket connection, and keeps everything in sync. All communication stays on `localhost` — your data never leaves your machine.

---

## 📦 Project Structure

```
├── Package.swift
├── Sources/
│   └── SparksMissionControl/
│       ├── App.swift                    # @main entry, window config
│       ├── Models/
│       │   ├── AppState.swift           # Observable app state
│       │   ├── GatewayConfig.swift      # Config file reader
│       │   └── GatewayConnection.swift  # WebSocket manager
│       ├── Views/
│       │   ├── DashboardView.swift      # Main layout
│       │   ├── ChatView.swift           # Live chat panel
│       │   ├── IdentityCard.swift       # Agent identity
│       │   ├── ServicesCard.swift       # Service status
│       │   ├── QuickActionsCard.swift   # Action buttons
│       │   ├── ActivityLogCard.swift    # Event stream
│       │   ├── CronJobsCard.swift       # Cron management
│       │   ├── ModelRoutingCard.swift   # Model display
│       │   ├── SkillsCard.swift         # Skills list
│       │   ├── NodeCard.swift           # Node info
│       │   └── GlassCard.swift          # Reusable glass component
│       └── Styles/
│           └── Theme.swift              # Colors, fonts, constants
└── build-and-install.sh
```

---

## 🚀 Getting Started

### Prerequisites

- **[OpenClaw](https://github.com/openclaw/openclaw)** installed and running
- **macOS 14.0+** (Sonoma or later)
- **Swift 6.2+** (included with Xcode 26+)

### Build & Run

```bash
# Clone
git clone https://github.com/joeynyc/sparks-mission-control.git
cd sparks-mission-control

# Build and launch
swift build
.build/debug/SparksMissionControl
```

### Install as App

```bash
# Build, bundle as .app, and launch
./build-and-install.sh
```

This creates `~/Applications/Sparks Mission Control.app` — drag it to your Dock.

---

## ⚙️ Configuration

The app auto-discovers your OpenClaw setup by reading local files from `~/.openclaw/` and your `clawd` workspace:

| Source | What it powers | Fallback |
|---|---|---|
| `~/.openclaw/openclaw.json` | Gateway port/auth token, model routing, and node metadata | Built-in defaults |
| `~/.openclaw/clawd/IDENTITY.md` or `~/clawd/IDENTITY.md` | Agent branding (`Name`, `Creature`, `Vibe`, `Emoji`) | `Agent`, `AI Assistant`, `🤖` |
| `~/.openclaw/clawd/USER.md` or `~/clawd/USER.md` | Owner display name (`Name`) | `User` |
| `~/.openclaw/skills`, `~/clawd/skills`, `/opt/homebrew/lib/node_modules/openclaw/skills` | Installed skills shown in dashboard | Empty list |

No manual configuration is required. If OpenClaw is running, Mission Control connects automatically.

---

## 🧩 Customization

Branding is controlled by your OpenClaw identity files, so the UI automatically reflects your agent and owner.

Use `IDENTITY.md` to set:

| Field | Example |
|---|---|
| `Name:` | `Nova` |
| `Creature:` | `Research Copilot` |
| `Vibe:` | `Calm, precise, no-fluff` |
| `Emoji:` | `🛰️` |

Use `USER.md` to set:

| Field | Example |
|---|---|
| `Name:` | `Alex` |

---

## 🎨 Design Language

- **Dark Glass** — Near-black translucent panels with subtle material effects
- **Electric Yellow** (`#FFD60A`) — signature accent
- **System Green** (`#30D158`) — Online / active states
- **SF Mono** — Technical values and logs
- **16pt corner radius** — Consistent card geometry
- Native macOS window chrome with transparent titlebar

---

## 🛠️ Tech Stack

| Technology | Usage |
|---|---|
| **SwiftUI** | Declarative UI framework |
| **Swift Package Manager** | Build system & dependency management |
| **URLSessionWebSocketTask** | Real-time gateway communication |
| **Combine / async-await** | Reactive state management |
| **AppKit** | Window configuration & native integration |

---

## 🗺️ Roadmap

- [ ] Notification center integration
- [ ] Menu bar quick-access widget
- [ ] Multi-agent session management
- [ ] Custom theme editor
- [ ] Plugin system for community panels
- [ ] Touch Bar support
- [ ] Keyboard shortcuts for all actions

---

## 🤝 Contributing

Contributions welcome. Open an issue or submit a PR.

1. Fork it
2. Create your branch (`git checkout -b feature/awesome`)
3. Commit (`git commit -m 'Add awesome feature'`)
4. Push (`git push origin feature/awesome`)
5. Open a PR

---

## 📄 License

MIT © Joey Rodriguez

---

<p align="center">
  <strong>⚡ Built by <a href="https://github.com/joeynyc">Joey Rodriguez</a></strong><br/>
  <em>Powered by OpenClaw · Claude · SwiftUI</em>
</p>
