import ArgumentParser
import AppKit

struct InspectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "查看原始 AX 树结构")

    @Option(name: .long, help: "目标应用名（默认前台应用）")
    var app: String?

    @Option(name: .long, help: "最大树深度（默认 5）")
    var maxDepth: Int = 5

    @Flag(name: .long, help: "显示详细属性（frame/value/description）")
    var detailed = false

    @Flag(name: .long, help: "人类可读格式输出")
    var human = false

    func run() async throws {
        try Permissions.ensureAccessibility()
        let engine = AccessibilityEngine(maxDepth: maxDepth)
        guard let pid = (app.flatMap { engine.findApp(name: $0) } ?? engine.frontmostApp()) else {
            Output.error("应用未找到: \(app ?? "frontmost")")
            throw ExitCode.failure
        }
        let tree = engine.getTree(pid: pid, maxDepth: maxDepth, detailed: detailed)
        let appName = app ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"

        if human {
            printTree(tree, indent: 0)
        } else {
            let result: [String: Any] = ["app": appName, "tree": tree]
            Output.print(result)
        }
    }

    private func printTree(_ node: [String: Any], indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        let role = node["role"] as? String ?? "?"
        let title = node["title"] as? String
        var display = title != nil ? "\(role) (\"\(title!)\")" : role
        if let value = node["value"] as? String, !value.isEmpty {
            let truncated = value.count > 40 ? String(value.prefix(40)) + "..." : value
            display += " val=\"\(truncated)\""
        }
        if let desc = node["description"] as? String, !desc.isEmpty {
            display += " desc=\"\(desc)\""
        }
        if let placeholder = node["placeholder"] as? String, !placeholder.isEmpty {
            display += " ph=\"\(placeholder)\""
        }
        if let help = node["help"] as? String, !help.isEmpty {
            display += " help=\"\(help)\""
        }
        if let subrole = node["subrole"] as? String, !subrole.isEmpty {
            display += " sub=\(subrole)"
        }
        if let domId = node["domId"] as? String, !domId.isEmpty {
            display += " #\(domId)"
        }
        if let frame = node["frame"] as? [String: Any] {
            let x = frame["x"] as? Double ?? 0
            let y = frame["y"] as? Double ?? 0
            let w = frame["w"] as? Double ?? 0
            let h = frame["h"] as? Double ?? 0
            display += " [\(Int(x)),\(Int(y)) \(Int(w))x\(Int(h))]"
        }
        print("\(prefix)\(display)")
        if let children = node["children"] as? [[String: Any]] {
            for child in children { printTree(child, indent: indent + 1) }
        }
    }
}
