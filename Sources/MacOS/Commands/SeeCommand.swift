import ArgumentParser
import AppKit

struct SeeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "see", abstract: "发现可交互 UI 元素（可选截图）")

    @Option(name: .long, help: "目标应用名（默认前台应用）")
    var app: String?

    @Option(name: .long, help: "截图保存路径")
    var screenshot: String?

    @Flag(name: .long, help: "在截图上标注元素 ID")
    var annotate = false

    @Option(name: .long, help: "AX 树最大遍历深度（默认 10）")
    var maxDepth: Int = 10

    @Flag(name: .long, help: "人类可读格式输出")
    var human = false

    func run() async throws {
        try Permissions.ensureAccessibility()
        let engine = AccessibilityEngine(maxDepth: maxDepth)
        guard let pid = (app.flatMap { engine.findApp(name: $0) } ?? engine.frontmostApp()) else {
            Output.error("应用未找到: \(app ?? "frontmost")")
            throw ExitCode.failure
        }
        let elements = engine.discoverElements(pid: pid)
        let appName = app ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"

        if let path = screenshot {
            if #available(macOS 14.0, *) {
                try await ScreenCapture.captureWindow(pid: pid, saveTo: path)
            }
        }

        if human {
            print("应用: \(appName) | 元素数: \(elements.count)")
            for el in elements {
                let label = el.title ?? el.value ?? ""
                print("  \(el.id) [\(el.role)] \(label)")
            }
            if let s = screenshot { print("截图: \(s)") }
        } else {
            Output.printCodable(SeeResult(app: appName, screenshot: screenshot, elements: elements))
        }
    }
}

struct SeeResult: Codable {
    let app: String
    let screenshot: String?
    let elements: [UIElement]
}
