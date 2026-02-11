import AppKit
import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""

    var body: some View {
        GlassCard(title: "Chat", icon: "💬") {
            VStack(spacing: 10) {
                ScrollViewReader { proxy in
                    ScrollView {
                        if appState.messages.isEmpty {
                            VStack(spacing: 10) {
                                Spacer(minLength: 40)
                                ZStack {
                                    Circle()
                                        .fill(Theme.accentYellow.opacity(0.06))
                                        .frame(width: 80, height: 80)
                                        .blur(radius: 12)
                                    Text(appState.agentIdentity.emoji)
                                        .font(.system(size: 38))
                                }
                                Text("Message \(appState.agentIdentity.name)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                                Text("Sends via gateway webhook → agent run")
                                    .font(Theme.mono(10))
                                    .foregroundStyle(Theme.textTertiary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(appState.messages) { message in
                                    MessageRow(message: message)
                                        .id(message.id)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .onChange(of: appState.messages.count) {
                        guard let lastID = appState.messages.last?.id else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .frame(minHeight: 280)

                HStack(spacing: 10) {
                    ChatTextField(
                        text: $draft,
                        placeholder: "Message \(appState.agentIdentity.name)...",
                        onSubmit: sendMessage
                    )
                        .frame(height: 42)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Theme.textTertiary
                                    : Theme.accentYellow
                            )
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        appState.sendChat(text: text)
    }
}

// MARK: - Native NSTextField wrapper for reliable keyboard input

struct ChatTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = PaddedTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(white: 1.0, alpha: 0.3),
                .font: NSFont.systemFont(ofSize: 14, weight: .regular),
            ]
        )
        field.isBordered = false
        field.isBezeled = false
        field.focusRingType = .none
        field.drawsBackground = true
        field.backgroundColor = NSColor(white: 0.06, alpha: 0.95)
        field.textColor = .white
        field.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.wantsLayer = true
        field.layer?.cornerRadius = 12
        field.layer?.borderColor = NSColor(white: 1.0, alpha: 0.10).cgColor
        field.layer?.borderWidth = 0.5
        field.layer?.masksToBounds = true

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: ChatTextField

        init(_ parent: ChatTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

// MARK: - Padded Text Field

private class PaddedTextFieldCell: NSTextFieldCell {
    private let inset = NSSize(width: 12, height: 0)

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: rect).insetBy(dx: inset.width, dy: inset.height)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: rect.insetBy(dx: inset.width, dy: inset.height), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: rect.insetBy(dx: inset.width, dy: inset.height), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

private class PaddedTextField: NSTextField {
    override class var cellClass: AnyClass? {
        get { PaddedTextFieldCell.self }
        set { super.cellClass = newValue }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: ChatMessage

    private var bubbleColor: Color {
        switch message.role {
        case .user: return Theme.accentYellow.opacity(0.92)
        case .assistant: return Color.white.opacity(0.1)
        case .system: return Theme.warningOrange.opacity(0.15)
        case .tool: return Theme.onlineGreen.opacity(0.12)
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user: return .black
        default: return .white.opacity(0.9)
        }
    }

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                if message.role == .tool {
                    Label("Tool", systemImage: "wrench.and.screwdriver")
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundStyle(Theme.onlineGreen)
                }

                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(textColor)
                    .textSelection(.enabled)

                Text(message.timestamp, style: .time)
                    .font(Theme.mono(10))
                    .foregroundStyle(textColor.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(bubbleColor)
            )

            if message.role != .user { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
