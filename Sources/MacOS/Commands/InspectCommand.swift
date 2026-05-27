import ArgumentParser
import AppKit

struct InspectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "查看原始 AX 树结构")

    @Option(name: .long, help: "目标应用名（默认前台应用）")
    var app: String?

    @Option(name: .long, help: "最大树深度（默认 5）")
    var maxDepth: Int = 5

    @Flag(name: .long, help: "人类可读格式输出")
    var human = false

    func run() async throws {
        try Permissions.ensureAccessibility()
        let engine = AccessibilityEngine(maxDepth: maxDepth)
        guard let pid = (app.flatMap { engine.findApp(name: $0) } ?? engine.frontmostApp()) else {
            Output.error("应用未找到: \(app ?? "frontmost")")
            throw ExitCode.failure
        }
        let tree = engine.getTree(pid: pid, maxDepth: maxDepth)
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
        let display = title != nil ? "\(role) (\"\(title!)\")" : role
        print("\(prefix)\(display)")
        if let children = node["children"] as? [[String: Any]] {
            for child in children { printTree(child, indent: indent + 1) }
        }
    }
}
