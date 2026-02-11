import Foundation

struct AgentIdentity: Sendable {
    let name: String
    let creature: String
    let vibe: String?
    let emoji: String

    static let `default` = AgentIdentity(
        name: "Agent",
        creature: "AI Assistant",
        vibe: nil,
        emoji: "🤖"
    )

    static func loadFromDisk() -> AgentIdentity {
        guard
            let markdown = loadFirstFile(
                at: [
                    "~/.openclaw/clawd/IDENTITY.md",
                    "~/clawd/IDENTITY.md",
                ]
            )
        else {
            return .default
        }

        let name = parseField("Name", in: markdown) ?? AgentIdentity.default.name
        let creature = parseField("Creature", in: markdown) ?? AgentIdentity.default.creature
        let vibe = parseField("Vibe", in: markdown)
        let emoji = parseField("Emoji", in: markdown) ?? AgentIdentity.default.emoji

        return AgentIdentity(
            name: name,
            creature: creature,
            vibe: vibe,
            emoji: emoji
        )
    }

    static func loadOwnerName() -> String {
        guard
            let markdown = loadFirstFile(
                at: [
                    "~/.openclaw/clawd/USER.md",
                    "~/clawd/USER.md",
                ]
            )
        else {
            return "User"
        }

        return parseField("Name", in: markdown) ?? "User"
    }

    private static func loadFirstFile(at paths: [String]) -> String? {
        for path in paths {
            let expanded = NSString(string: path).expandingTildeInPath
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: expanded)) else { continue }
            guard let markdown = String(data: data, encoding: .utf8), !markdown.isEmpty else { continue }
            return markdown
        }
        return nil
    }

    private static func parseField(_ field: String, in markdown: String) -> String? {
        let pattern = "^\\s*[-*+>]*\\s*(?:\\*\\*|__)?\(NSRegularExpression.escapedPattern(for: field))(?:\\*\\*|__)?\\s*:\\s*(.+?)\\s*$"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]),
            let match = regex.firstMatch(
                in: markdown,
                options: [],
                range: NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            ),
            let valueRange = Range(match.range(at: 1), in: markdown)
        else {
            return nil
        }

        let rawValue = String(markdown[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = stripMarkdownWrappers(from: rawValue)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func stripMarkdownWrappers(from value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let wrappers = ["**", "__", "`", "*", "_"]
        for wrapper in wrappers {
            while trimmed.hasPrefix(wrapper), trimmed.hasSuffix(wrapper), trimmed.count >= wrapper.count * 2 {
                trimmed.removeFirst(wrapper.count)
                trimmed.removeLast(wrapper.count)
                trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return trimmed
    }
}
