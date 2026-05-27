import ArgumentParser
import ApplicationServices
import AppKit

struct WindowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "window", abstract: "管理窗口")

    @Option(name: .long, help: "操作: move, resize, close, minimize, maximize, focus, list")
    var action: String

    @Option(name: .long, help: "目标应用名")
    var app: String?

    @Option(name: .long, help: "窗口标题（部分匹配）")
    var title: String?

    @Option(name: .long, help: "X 位置")
    var x: Double?

    @Option(name: .long, help: "Y 位置")
    var y: Double?

    @Option(name: .long, help: "宽度")
    var width: Double?

    @Option(name: .long, help: "高度")
    var height: Double?

    func run() async throws {
        try Permissions.ensureAccessibility()

        guard let appName = app else {
            if action == "list" {
                listAllWindows()
                return
            }
            Output.error("需要 --app 参数")
            throw ExitCode.failure
        }

        let engine = AccessibilityEngine()
        guard let pid = engine.findApp(name: appName) else {
            Output.error("应用未找到: \(appName)")
            throw ExitCode.failure
        }

        let appElement = AXUIElementCreateApplication(pid)
        guard let window = findWindow(appElement: appElement) else {
            Output.error("窗口未找到: \(appName)")
            throw ExitCode.failure
        }

        switch action.lowercased() {
        case "move":
            guard let x = x, let y = y else {
                Output.error("move 需要 --x 和 --y")
                throw ExitCode.failure
            }
            var point = CGPoint(x: x, y: y)
            if let value = AXValueCreate(.cgPoint, &point) {
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
            }

        case "resize":
            guard let w = width, let h = height else {
                Output.error("resize 需要 --width 和 --height")
                throw ExitCode.failure
            }
            var size = CGSize(width: w, height: h)
            if let value = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
            }

        case "close":
            pressWindowButton(window, attribute: kAXCloseButtonAttribute)

        case "minimize":
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, true as CFBoolean)

        case "maximize":
            pressWindowButton(window, attribute: kAXFullScreenButtonAttribute as String)

        case "focus":
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, true as CFBoolean)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        case "list":
            listAppWindows(appElement: appElement, appName: appName)
            return

        default:
            Output.error("未知操作: \(action)")
            throw ExitCode.failure
        }

        Output.printCodable(WindowResult(action: action, app: appName, success: true))
    }

    private func findWindow(appElement: AXUIElement) -> AXUIElement? {
        var windowsRef: AnyObject?
        AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard let windows = windowsRef as? [AXUIElement] else { return nil }

        if let titleQuery = title {
            for win in windows {
                var titleRef: AnyObject?
                AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                if let winTitle = titleRef as? String, winTitle.localizedCaseInsensitiveContains(titleQuery) {
                    return win
                }
            }
        }
        return windows.first
    }

    private func pressWindowButton(_ window: AXUIElement, attribute: String) {
        var buttonRef: AnyObject?
        AXUIElementCopyAttributeValue(window, attribute as CFString, &buttonRef)
        if let button = buttonRef as! AXUIElement? {
            AXUIElementPerformAction(button, kAXPressAction as CFString)
        }
    }

    private func listAppWindows(appElement: AXUIElement, appName: String) {
        var windowsRef: AnyObject?
        AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard let windows = windowsRef as? [AXUIElement] else {
            Output.printCodable([WindowInfo]())
            return
        }
        var infos: [WindowInfo] = []
        for (i, win) in windows.enumerated() {
            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
            infos.append(WindowInfo(index: i, title: titleRef as? String ?? "", app: appName))
        }
        Output.printCodable(infos)
    }

    private func listAllWindows() {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        var allWindows: [WindowInfo] = []
        for app in apps {
            guard let name = app.localizedName else { continue }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: AnyObject?
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            if let windows = windowsRef as? [AXUIElement] {
                for (i, win) in windows.enumerated() {
                    var titleRef: AnyObject?
                    AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                    allWindows.append(WindowInfo(index: i, title: titleRef as? String ?? "", app: name))
                }
            }
        }
        Output.printCodable(allWindows)
    }
}

struct WindowResult: Codable {
    let action: String
    let app: String
    let success: Bool
}

struct WindowInfo: Codable {
    let index: Int
    let title: String
    let app: String
}
