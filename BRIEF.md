# Sparks Mission Control — Fully Integrated Native macOS App

Build a standalone macOS SwiftUI app (Swift Package Manager) called "Sparks Mission Control".
This is NOT a static dashboard — every feature must be LIVE and FUNCTIONAL.

## Architecture: Gateway Integration

The app communicates with the OpenClaw gateway running at `ws://127.0.0.1:18789`.

### Reading Config
On launch, read `~/.openclaw/openclaw.json` to extract:
- `gateway.port` (default 18789)
- `gateway.auth.token` (for auth)

### WebSocket Connection
Connect to the gateway WebSocket (same protocol as the TUI):
- URL: `ws://127.0.0.1:{port}`
- Send auth token on connect
- Register as mode "app" or "tui"
- Listen for streaming responses, tool events, system notices

### HTTP Webhook API
For quick fire-and-forget commands, POST to:
- `POST http://127.0.0.1:{port}/hooks/wake` — send wake events
- `POST http://127.0.0.1:{port}/hooks/agent` — trigger agent runs
- Auth: `Authorization: Bearer {token}` header

### CLI Commands (fallback)
For some features, shell out to `openclaw` CLI:
- `openclaw status` — gateway status
- `openclaw cron list` — list cron jobs
- `openclaw models status` — model info

## Design: Black Liquid Glass
- Deep black translucent glass — near-black (#0A0A0A) base
- Use `.ultraThinMaterial` / `.regularMaterial` with forced dark appearance
- Subtle ambient color gradients in background
- Cards: dark translucent glass panels with subtle top highlight
- Accent: electric yellow (#FFD60A) for Sparks branding
- Green (#30D158) for online/active, Red (#FF453A) for errors, Orange (#FF9F0A) for warnings
- Monospace for technical values
- 16pt corner radius on cards
- macOS native window, transparent titlebar, full-size content view
- Window default 1280x900, min 900x600

## Sections & Features (ALL LIVE)

### 1. Title Bar
- Traffic lights
- "⚡ Sparks — Mission Control"
- Green beacon + "ONLINE" (actual WebSocket connection state)
- Live clock (EST)

### 2. Identity Card
- ⚡ avatar
- "Sparks — Live wire • Executive Assistant to Joey"
- Model: claude-opus-4-6
- Connection status indicator (connected/disconnected/reconnecting)

### 3. Chat Panel (CORE FEATURE)
A real chat interface where Joey can type messages to Sparks and see responses streamed back:
- Text input field at bottom
- Messages display area (scrollable)
- User messages right-aligned, Sparks responses left-aligned
- Streaming text support (responses appear word by word)
- Tool call indicators (show when Sparks is using tools)
- Send via WebSocket to gateway

### 4. Quick Actions (FUNCTIONAL)
Buttons that send real commands to the gateway:
- **Search Memory** → sends "search memory for: {user input}" via agent hook
- **Web Search** → sends "search the web for: {user input}" via agent hook  
- **List Cron Jobs** → runs `openclaw cron list` and displays output
- **Gateway Status** → runs `openclaw status` and displays output
- **Ping Node** → sends "ping the Mac mini node" via agent hook
- **Spawn Sub-Agent** → sends "spawn a sub-agent to: {user input}" via agent hook
- **Gateway Restart** → runs `openclaw gateway restart` (with confirmation dialog)

Each quick action should open a small sheet/popover for input if needed, then show results.

### 5. Services Status (LIVE)
Poll gateway status periodically (every 30s) to show:
- Gateway: Running/Stopped (check WebSocket connection)
- Telegram: Connected/Disconnected (from gateway status)
- Show connection uptime

### 6. Activity Log (LIVE)
Real-time log of:
- Messages sent/received via the chat
- Tool calls being executed
- System events
- Timestamps for everything
- Auto-scroll, max 100 entries

### 7. Cron Jobs Panel (LIVE)
- Fetch and display real cron jobs from `openclaw cron list --json`
- Show name, schedule, enabled/disabled status
- Button to trigger a job manually

### 8. Model Routing (DISPLAY from config)
Read from openclaw.json and display:
- Primary model
- Fallback models list
- Aliases

### 9. Skills Arsenal (DISPLAY)
Show installed skills (can hardcode the known list or read from filesystem)

### 10. Node Info (LIVE)
- Show Mac Mini node status
- IP, OS version
- Could poll via agent command

## Technical Requirements
- Swift Package Manager (Package.swift)
- macOS 14.0+ deployment target  
- SwiftUI with AppKit integration where needed
- URLSessionWebSocketTask for WebSocket
- JSONDecoder/JSONEncoder for gateway protocol
- Process/NSTask for CLI commands
- Combine or async/await for reactive updates
- Single window app
- All networking to localhost only

## File Structure
```
Package.swift
Sources/
  SparksMissionControl/
    App.swift                  — @main App, window setup
    Models/
      GatewayConnection.swift  — WebSocket connection manager
      GatewayConfig.swift      — Config file reader
      AppState.swift           — Observable app state
    Views/
      DashboardView.swift      — Main layout
      ChatView.swift           — Chat panel
      IdentityCard.swift       — Identity section
      ServicesCard.swift       — Services status
      QuickActionsCard.swift   — Quick action buttons
      ActivityLogCard.swift    — Activity log
      CronJobsCard.swift       — Cron jobs
      SkillsCard.swift         — Skills display
      NodeCard.swift           — Node info
      ModelRoutingCard.swift   — Model routing
      GlassCard.swift          — Reusable glass card component
    Styles/
      Theme.swift              — Colors, fonts, constants
```

## Gateway WebSocket Protocol (simplified)
The gateway uses JSON messages over WebSocket. Key message types:

Sending a user message:
```json
{"type":"user","content":"Hello Sparks"}
```

Receiving assistant response (streamed):
```json
{"type":"assistant","content":"Hey Joey!","streaming":true}
{"type":"assistant","content":"Hey Joey! How can I help?","streaming":false}
```

Tool call indication:
```json
{"type":"tool","name":"web_search","status":"running"}
{"type":"tool","name":"web_search","status":"done","result":"..."}
```

For now, if the exact WebSocket protocol is unclear, use the HTTP webhook API as primary:
- Send messages via `POST /hooks/agent` with `{"message":"...","sessionKey":"app:mission-control","deliver":false}`
- This is simpler and guaranteed to work

## CRITICAL
- Every button must DO something real
- The chat must actually talk to Sparks via the gateway
- Status indicators must reflect real connection state
- Read the actual gateway token from ~/.openclaw/openclaw.json
- The app must compile and run with `swift build && .build/debug/SparksMissionControl`

When completely finished and it compiles, run: openclaw gateway wake --text "Done: Built fully integrated Sparks Mission Control macOS app" --mode now
