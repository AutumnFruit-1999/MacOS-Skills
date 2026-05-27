import ArgumentParser
import AppKit

struct ClickCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "click", abstract: "点击 UI 元素或坐标")

    @Option(name: .long, help: "按文本内容实时查找元素并点击")
    var query: String?

    @Option(name: .long, help: "坐标 'x,y'")
    var coords: String?

    @Option(name: .long, help: "目标应用名（用于 query 搜索范围）")
    var app: String?

    @Flag(name: .long, help: "双击")
    var double = false

    @Flag(name: .long, help: "右键点击")
    var right = false

    func run() throws {
        try Permissions.ensureAccessibility()
        let point: CGPoint

        if let coordStr = coords {
            let parts = coordStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 2 else {
                Output.error("坐标格式错误，使用 'x,y'")
                throw ExitCode.failure
            }
            point = CGPoint(x: parts[0], y: parts[1])
        } else if let queryStr = query {
            let engine = AccessibilityEngine()
            let pid: pid_t
            if let appName = app {
                guard let p = engine.findApp(name: appName) else {
                    Output.error("应用未找到: \(appName)")
                    throw ExitCode.failure
                }
                pid = p
            } else {
                guard let p = engine.frontmostApp() else {
                    Output.error("无前台应用")
                    throw ExitCode.failure
                }
                pid = p
            }
            let elements = engine.discoverElements(pid: pid)
            guard let element = elements.first(where: {
                $0.title?.localizedCaseInsensitiveContains(queryStr) == true ||
                $0.value?.localizedCaseInsensitiveContains(queryStr) == true
            }), let frame = element.frame else {
                Output.error("未找到匹配 '\(queryStr)' 的元素")
                throw ExitCode.failure
            }
            point = CGPoint(x: frame.x + frame.w / 2, y: frame.y + frame.h / 2)
        } else {
            Output.error("请指定 --query 或 --coords")
            throw ExitCode.failure
        }

        EventEngine.click(at: point, button: right ? .right : .left, clickCount: double ? 2 : 1)
        Output.printCodable(ClickResult(clicked: true, x: point.x, y: point.y, button: right ? "right" : "left", clickCount: double ? 2 : 1))
    }
}

struct ClickResult: Codable {
    let clicked: Bool
    let x: Double
    let y: Double
    let button: String
    let clickCount: Int

    enum CodingKeys: String, CodingKey {
        case clicked, x, y, button
        case clickCount = "click_count"
    }
}
