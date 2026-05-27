import ArgumentParser
import AppKit
import ApplicationServices

struct AppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "app", abstract: "管理应用（启动/退出/聚焦/列表）")

    @Option(name: .long, help: "操作: launch, quit, focus, list")
    var action: String

    @Option(name: .long, help: "应用名")
    var name: String?

    @Flag(name: .long, help: "强制退出")
    var force = false

    @Flag(name: .long, help: "等待应用就绪")
    var wait = false

    @Flag(name: .long, help: "人类可读格式")
    var human = false

    func run() async throws {
        switch action.lowercased() {
        case "launch":
            guard let appName = name else {
                Output.error("launch 需要 --name")
                throw ExitCode.failure
            }
            let config = NSWorkspace.OpenConfiguration()
            if let url = findAppURL(name: appName) {
                let app = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
                if wait { usleep(2_000_000) }
                Output.printCodable(AppResult(action: "launch", app: appName, pid: app.processIdentifier))
            } else {
                Output.error("应用未找到: \(appName)")
                throw ExitCode.failure
            }

        case "quit":
            guard let appName = name else {
                Output.error("quit 需要 --name")
                throw ExitCode.failure
            }
            for app in NSWorkspace.shared.runningApplications where app.localizedName == appName {
                if force { app.forceTerminate() } else { app.terminate() }
            }
            Output.printCodable(AppResult(action: "quit", app: appName, pid: nil))

        case "focus":
            guard let appName = name else {
                Output.error("focus 需要 --name")
                throw ExitCode.failure
            }
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else {
                Output.error("应用未运行: \(appName)")
                throw ExitCode.failure
            }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: AnyObject?
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            let windows = windowsRef as? [AXUIElement] ?? []
            if windows.isEmpty {
                // 无窗口时（如微信关闭窗口后仍在 Dock 运行），通过 open 命令唤起
                if let bundleID = app.bundleIdentifier {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    task.arguments = ["-b", bundleID]
                    try? task.run()
                    task.waitUntilExit()
                }
            } else {
                for window in windows {
                    var minimizedRef: AnyObject?
                    AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef)
                    if let minimized = minimizedRef as? Bool, minimized {
                        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFBoolean)
                    }
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                }
            }
            app.activate()
            Output.printCodable(AppResult(action: "focus", app: appName, pid: app.processIdentifier))

        case "list":
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap { a -> AppInfo? in
                    guard let n = a.localizedName else { return nil }
                    return AppInfo(name: n, pid: a.processIdentifier, active: a.isActive)
                }
            if human {
                for a in apps { print("\(a.active ? "*" : " ") \(a.name) (PID: \(a.pid))") }
            } else {
                Output.printCodable(apps)
            }

        default:
            Output.error("未知操作: \(action)，使用: launch, quit, focus, list")
            throw ExitCode.failure
        }
    }

    private func findAppURL(name: String) -> URL? {
        for dir in ["/Applications", "/System/Applications", "/Applications/Utilities"] {
            let url = URL(fileURLWithPath: "\(dir)/\(name).app")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}

struct AppResult: Codable {
    let action: String
    let app: String
    let pid: Int32?
}

struct AppInfo: Codable {
    let name: String
    let pid: Int32
    let active: Bool
}
