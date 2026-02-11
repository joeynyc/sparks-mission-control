import Foundation

struct ModelRoutingInfo: Sendable {
    var primary: String
    var fallbackModels: [String]
    var aliases: [String: String]
}

struct GatewayConfig: Sendable {
    let port: Int
    let gatewayToken: String   // gateway.auth.token — for health checks
    let hooksToken: String     // hooks.token — for /hooks/* API
    let modelRouting: ModelRoutingInfo
    let nodeName: String

    /// Convenience — the token used for HTTP health checks
    var token: String { gatewayToken }

    static let defaultPort = 18_789
    static let defaultSessionKey = "app:mission-control"

    static func loadFromDisk() -> GatewayConfig {
        let path = NSString(string: "~/.openclaw/openclaw.json").expandingTildeInPath
        let url = URL(fileURLWithPath: path)

        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return GatewayConfig(
                port: defaultPort,
                gatewayToken: "",
                hooksToken: "",
                modelRouting: ModelRoutingInfo(primary: "claude-opus-4-6", fallbackModels: [], aliases: [:]),
                nodeName: "Connected Node"
            )
        }

        let port = integer(
            in: object,
            paths: [
                ["gateway", "port"],
                ["port"],
            ],
            defaultValue: defaultPort
        )

        let gatewayToken = string(
            in: object,
            paths: [
                ["gateway", "auth", "token"],
            ],
            defaultValue: ""
        )

        let hooksToken = string(
            in: object,
            paths: [
                ["hooks", "token"],
            ],
            defaultValue: ""
        )

        let primary = string(
            in: object,
            paths: [
                ["agents", "defaults", "model", "primary"],
            ],
            defaultValue: "claude-opus-4-6"
        )

        let fallbacks = stringArray(
            in: object,
            paths: [
                ["agents", "defaults", "model", "fallbacks"],
            ]
        )

        let aliasesRaw = value(in: object, path: ["agents", "defaults", "models"]) as? [String: Any] ?? [:]
        var aliases: [String: String] = [:]
        for (key, val) in aliasesRaw {
            if let dict = val as? [String: Any], let alias = dict["alias"] as? String {
                aliases[key] = alias
            }
        }

        let nodeName = nodeDisplayName(in: object) ?? "Connected Node"

        return GatewayConfig(
            port: port,
            gatewayToken: gatewayToken,
            hooksToken: hooksToken,
            modelRouting: ModelRoutingInfo(primary: primary, fallbackModels: fallbacks, aliases: aliases),
            nodeName: nodeName
        )
    }

    private static func integer(in root: [String: Any], paths: [[String]], defaultValue: Int) -> Int {
        for path in paths {
            if let value = value(in: root, path: path) {
                if let int = value as? Int {
                    return int
                }
                if let string = value as? String, let int = Int(string) {
                    return int
                }
            }
        }
        return defaultValue
    }

    private static func string(in root: [String: Any], paths: [[String]], defaultValue: String) -> String {
        for path in paths {
            if let value = value(in: root, path: path) as? String, !value.isEmpty {
                return value
            }
        }
        return defaultValue
    }

    private static func stringArray(in root: [String: Any], paths: [[String]]) -> [String] {
        for path in paths {
            if let values = value(in: root, path: path) as? [String] {
                return values
            }
            if let values = value(in: root, path: path) as? [Any] {
                let strings = values.compactMap { $0 as? String }
                if !strings.isEmpty {
                    return strings
                }
            }
        }
        return []
    }

    private static func stringDictionary(in root: [String: Any], paths: [[String]]) -> [String: String] {
        for path in paths {
            if let dict = value(in: root, path: path) as? [String: String] {
                return dict
            }
            if let dict = value(in: root, path: path) as? [String: Any] {
                var result: [String: String] = [:]
                for (key, value) in dict {
                    if let string = value as? String {
                        result[key] = string
                    }
                }
                if !result.isEmpty {
                    return result
                }
            }
        }
        return [:]
    }

    private static func nodeDisplayName(in root: [String: Any]) -> String? {
        if let explicit = optionalString(
            in: root,
            paths: [
                ["node", "name"],
                ["nodes", "default", "name"],
                ["nodes", "local", "name"],
                ["agents", "defaults", "node", "name"],
                ["gateway", "node", "name"],
            ]
        ) {
            return explicit
        }

        if
            let nodes = value(in: root, path: ["nodes"]) as? [String: Any] {
            for value in nodes.values {
                if
                    let node = value as? [String: Any],
                    let name = node["name"] as? String,
                    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return name
                }
            }
        }

        return nil
    }

    private static func optionalString(in root: [String: Any], paths: [[String]]) -> String? {
        for path in paths {
            if let value = value(in: root, path: path) as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func value(in root: [String: Any], path: [String]) -> Any? {
        var current: Any = root
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }
        return current
    }
}
