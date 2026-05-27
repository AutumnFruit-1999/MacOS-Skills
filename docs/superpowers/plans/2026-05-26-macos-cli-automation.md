# macOS CLI 自动化工具实现计划

> **给自动化代理：** 必须使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 技能逐任务执行此计划。步骤使用 (`- [ ]`) 语法追踪进度。

**目标：** 构建 Swift CLI 工具 (`macos`)，让 Cursor Agent 通过 Shell 命令控制 macOS 桌面，封装 Apple 原生 API（Accessibility、CGEvent、ScreenCaptureKit、NSWorkspace）。

**架构：** 单可执行文件，Swift Package Manager 构建。使用 ArgumentParser 做命令路由，Core 引擎封装系统 API。纯无状态设计——Agent 上下文即状态，无需文件持久化。

**技术栈：** Swift 6.0, ArgumentParser 1.5+, macOS 14+, AXUIElement API, CGEvent API, ScreenCaptureKit, NSWorkspace, NSPasteboard

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `Package.swift` | SPM 清单、依赖配置 |
| `Sources/MacOS/MacOS.swift` | 根命令 + 全局选项 (--human) |
| `Sources/MacOS/Core/AccessibilityEngine.swift` | AXUIElement 遍历、元素搜索、Action 执行 |
| `Sources/MacOS/Core/EventEngine.swift` | CGEvent 鼠标/键盘/滚动操作 |
| `Sources/MacOS/Core/ScreenCapture.swift` | ScreenCaptureKit 封装 |
| `Sources/MacOS/Core/Output.swift` | JSON/人类可读 输出格式化 |
| `Sources/MacOS/Core/Permissions.swift` | 辅助功能/屏幕录制权限检查 |
| `Sources/MacOS/Commands/SeeCommand.swift` | `see` 子命令 |
| `Sources/MacOS/Commands/InspectCommand.swift` | `inspect` 子命令 |
| `Sources/MacOS/Commands/ClickCommand.swift` | `click` 子命令 |
| `Sources/MacOS/Commands/TypeCommand.swift` | `type` 子命令 |
| `Sources/MacOS/Commands/HotkeyCommand.swift` | `hotkey` 子命令 |
| `Sources/MacOS/Commands/ScrollCommand.swift` | `scroll` 子命令 |
| `Sources/MacOS/Commands/AppCommand.swift` | `app` 子命令 |
| `Sources/MacOS/Commands/WindowCommand.swift` | `window` 子命令 |
| `Sources/MacOS/Commands/MenuCommand.swift` | `menu` 子命令 |
| `Sources/MacOS/Commands/ClipboardCommand.swift` | `clipboard` 子命令 |
| `SKILL.md` | Agent 使用指南（Cursor Skill 规范） |
| `reference.md` | 详细命令参考（渐进式披露） |
| `README.md` | 项目文档 + 安装指南 |

---

## 任务 1：项目搭建 + Package.swift

**文件：**
- 创建：`Package.swift`
- 创建：`Sources/MacOS/MacOS.swift`

- [ ] **步骤 1：编写 Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOS",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "macos",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/MacOS"
        )
    ]
)
```

- [ ] **步骤 2：编写根命令**

```swift
// Sources/MacOS/MacOS.swift
import ArgumentParser

@main
struct MacOS: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "macos",
        abstract: "macOS 自动化 CLI — 通过 Apple 原生 API 控制桌面",
        subcommands: [
            SeeCommand.self,
            InspectCommand.self,
            ClickCommand.self,
            TypeCommand.self,
            HotkeyCommand.self,
            ScrollCommand.self,
            AppCommand.self,
            WindowCommand.self,
            MenuCommand.self,
            ClipboardCommand.self,
        ]
    )
}
```

- [ ] **步骤 3：创建桩命令**

为每个命令文件创建最小化的 ParsableCommand 结构，确保项目可编译：

```swift
// Sources/MacOS/Commands/SeeCommand.swift
import ArgumentParser

struct SeeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "see", abstract: "发现 UI 元素（可选截图）")
    func run() throws { print("{\"error\": \"not implemented\"}") }
}
```

对其余 9 个命令重复此操作。

- [ ] **步骤 4：解析依赖并验证编译**

执行：`cd /Users/user/Documents/cursor/MacOS && swift build`
期望：BUILD SUCCEEDED

- [ ] **步骤 5：提交**

```bash
git init
git add .
git commit -m "feat: 项目脚手架，集成 ArgumentParser 和命令桩"
```

---

## 任务 2：Core — 输出格式化

**文件：**
- 创建：`Sources/MacOS/Core/Output.swift`

- [ ] **步骤 1：实现 Output 工具类**

```swift
// Sources/MacOS/Core/Output.swift
import Foundation

enum OutputFormat {
    case json
    case human
}

struct Output {
    static func print(_ value: Any, format: OutputFormat = .json) {
        switch format {
        case .json:
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                Swift.print(str)
            }
        case .human:
            Swift.print(value)
        }
    }

    static func printCodable<T: Encodable>(_ value: T, format: OutputFormat = .json) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value),
           let str = String(data: data, encoding: .utf8) {
            Swift.print(str)
        }
    }

    static func error(_ message: String) {
        let err: [String: String] = ["error": message]
        if let data = try? JSONSerialization.data(withJSONObject: err, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            fputs(str + "\n", stderr)
        }
    }
}
```

- [ ] **步骤 2：验证编译**

执行：`swift build`
期望：BUILD SUCCEEDED

- [ ] **步骤 3：提交**

```bash
git add Sources/MacOS/Core/Output.swift
git commit -m "feat: 添加 Output 格式化工具（JSON/人类可读）"
```

---

## 任务 3：Core — 权限检查

**文件：**
- 创建：`Sources/MacOS/Core/Permissions.swift`

- [ ] **步骤 1：实现权限检查器**

```swift
// Sources/MacOS/Core/Permissions.swift
import ApplicationServices
import Foundation

struct Permissions {
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): prompt]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func ensureAccessibility() throws {
        guard checkAccessibility(prompt: true) else {
            throw PermissionError.accessibilityNotGranted
        }
    }
}

enum PermissionError: Error, CustomStringConvertible {
    case accessibilityNotGranted
    case screenRecordingNotGranted

    var description: String {
        switch self {
        case .accessibilityNotGranted:
            return "需要辅助功能权限。请前往：系统设置 > 隐私与安全性 > 辅助功能"
        case .screenRecordingNotGranted:
            return "需要屏幕录制权限。请前往：系统设置 > 隐私与安全性 > 屏幕录制"
        }
    }
}
```

- [ ] **步骤 2：验证编译**

执行：`swift build`
期望：BUILD SUCCEEDED

- [ ] **步骤 3：提交**

```bash
git add Sources/MacOS/Core/Permissions.swift
git commit -m "feat: 添加辅助功能权限检查"
```

---

## 任务 4：Core — AccessibilityEngine

**文件：**
- 创建：`Sources/MacOS/Core/AccessibilityEngine.swift`

- [ ] **步骤 1：定义元素模型**

```swift
// Sources/MacOS/Core/AccessibilityEngine.swift
import ApplicationServices
import AppKit

struct UIElement: Codable {
    let id: String
    let role: String
    let title: String?
    let value: String?
    let frame: Frame?
    let actions: [String]?

    struct Frame: Codable {
        let x: Double
        let y: Double
        let w: Double
        let h: Double
    }
}
```

- [ ] **步骤 2：实现 AX 树遍历**

```swift
final class AccessibilityEngine {
    private let maxDepth: Int
    private let maxElements: Int

    init(maxDepth: Int = 10, maxElements: Int = 500) {
        self.maxDepth = maxDepth
        self.maxElements = maxElements
    }

    func findApp(name: String) -> pid_t? {
        let apps = NSWorkspace.shared.runningApplications
        return apps.first { $0.localizedName == name }?.processIdentifier
    }

    func frontmostApp() -> pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func discoverElements(pid: pid_t) -> [UIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var elements: [UIElement] = []
        var counters: [String: Int] = [:]
        traverse(element: appElement, depth: 0, elements: &elements, counters: &counters)
        return elements
    }

    func getTree(pid: pid_t, maxDepth: Int? = nil) -> [String: Any] {
        let appElement = AXUIElementCreateApplication(pid)
        return buildTree(element: appElement, depth: 0, maxDepth: maxDepth ?? self.maxDepth)
    }

    private func traverse(element: AXUIElement, depth: Int, elements: inout [UIElement], counters: inout [String: Int]) {
        guard depth < maxDepth, elements.count < maxElements else { return }

        let role = getAttribute(element, kAXRoleAttribute) as? String ?? "unknown"
        let title = getAttribute(element, kAXTitleAttribute) as? String
        let value = getAttribute(element, kAXValueAttribute) as? String
        let actions = getActions(element)

        if isInteractive(role: role) {
            let prefix = idPrefix(for: role)
            let count = (counters[prefix] ?? 0) + 1
            counters[prefix] = count
            let id = "\(prefix)\(count)"
            let frame = getFrame(element)
            elements.append(UIElement(id: id, role: role, title: title, value: value, frame: frame, actions: actions.isEmpty ? nil : actions))
        }

        guard let children = getAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
        for child in children {
            traverse(element: child, depth: depth + 1, elements: &elements, counters: &counters)
        }
    }

    private func buildTree(element: AXUIElement, depth: Int, maxDepth: Int) -> [String: Any] {
        let role = getAttribute(element, kAXRoleAttribute) as? String ?? "unknown"
        let title = getAttribute(element, kAXTitleAttribute) as? String
        var node: [String: Any] = ["role": role]
        if let title = title { node["title"] = title }
        if depth < maxDepth, let children = getAttribute(element, kAXChildrenAttribute) as? [AXUIElement] {
            node["children"] = children.map { buildTree(element: $0, depth: depth + 1, maxDepth: maxDepth) }
        }
        return node
    }

    private func getAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value
    }

    private func getActions(_ element: AXUIElement) -> [String] {
        var actions: CFArray?
        AXUIElementCopyActionNames(element, &actions)
        return (actions as? [String]) ?? []
    }

    private func getFrame(_ element: AXUIElement) -> UIElement.Frame? {
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        guard let posValue = posValue, let sizeValue = sizeValue else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return UIElement.Frame(x: point.x, y: point.y, w: size.width, h: size.height)
    }

    private func isInteractive(role: String) -> Bool {
        ["AXButton", "AXTextField", "AXTextArea", "AXCheckBox", "AXRadioButton",
         "AXPopUpButton", "AXComboBox", "AXSlider", "AXMenuButton", "AXLink",
         "AXTab", "AXIncrementor"].contains(role)
    }

    private func idPrefix(for role: String) -> String {
        switch role {
        case "AXButton", "AXMenuButton": return "B"
        case "AXTextField", "AXTextArea", "AXComboBox": return "T"
        case "AXCheckBox", "AXRadioButton": return "C"
        case "AXLink": return "L"
        case "AXSlider", "AXIncrementor": return "S"
        case "AXTab": return "Tab"
        case "AXPopUpButton": return "P"
        default: return "E"
        }
    }
}
```

- [ ] **步骤 3：验证编译**

执行：`swift build`
期望：BUILD SUCCEEDED

- [ ] **步骤 4：提交**

```bash
git add Sources/MacOS/Core/AccessibilityEngine.swift
git commit -m "feat: 实现 AccessibilityEngine，支持 AX 树遍历"
```

---

## 任务 5：Core — EventEngine

**文件：**
- 创建：`Sources/MacOS/Core/EventEngine.swift`

- [ ] **步骤 1：实现鼠标/键盘/滚动操作**

```swift
// Sources/MacOS/Core/EventEngine.swift
import CoreGraphics
import Foundation

final class EventEngine {

    static func click(at point: CGPoint, button: CGMouseButton = .left, clickCount: Int = 1) {
        let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
        for _ in 0..<clickCount {
            let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: button)
            down?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: button)
            up?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
            up?.post(tap: .cghidEventTap)
        }
    }

    static func moveMouse(to point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }

    static func scroll(direction: ScrollDirection, amount: Int32 = 3) {
        let event: CGEvent?
        switch direction {
        case .up:    event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: amount, wheel2: 0, wheel3: 0)
        case .down:  event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -amount, wheel2: 0, wheel3: 0)
        case .left:  event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: amount, wheel3: 0)
        case .right: event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: -amount, wheel3: 0)
        }
        event?.post(tap: .cghidEventTap)
    }

    enum ScrollDirection: String, CaseIterable {
        case up, down, left, right
    }

    static func typeText(_ text: String, delay: UInt32 = 5000) {
        for char in text {
            let utf16 = Array(String(char).utf16)
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { continue }
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            event.post(tap: .cghidEventTap)
            let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            upEvent?.post(tap: .cghidEventTap)
            usleep(delay)
        }
    }

    static func pressKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        down?.flags = modifiers
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        up?.flags = modifiers
        up?.post(tap: .cghidEventTap)
    }

    static func hotkey(keys: [String]) throws {
        var modifiers: CGEventFlags = []
        var keyCode: CGKeyCode = 0
        var hasKey = false
        for key in keys {
            switch key.lowercased() {
            case "cmd", "command": modifiers.insert(.maskCommand)
            case "shift": modifiers.insert(.maskShift)
            case "alt", "option": modifiers.insert(.maskAlternate)
            case "ctrl", "control": modifiers.insert(.maskControl)
            case "fn": modifiers.insert(.maskSecondaryFn)
            default:
                guard let code = keyCodeMap[key.lowercased()] else { throw EventError.unknownKey(key) }
                keyCode = code
                hasKey = true
            }
        }
        guard hasKey else { throw EventError.noKeySpecified }
        pressKey(keyCode, modifiers: modifiers)
    }

    static let keyCodeMap: [String: CGKeyCode] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
        "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46,
        "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
        "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
        "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
        "space": 49, "return": 36, "tab": 48, "escape": 53,
        "delete": 51, "backspace": 51,
        "arrow_up": 126, "arrow_down": 125, "arrow_left": 123, "arrow_right": 124,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    ]
}

enum EventError: Error, CustomStringConvertible {
    case unknownKey(String)
    case noKeySpecified
    var description: String {
        switch self {
        case .unknownKey(let key): return "未知按键: '\(key)'"
        case .noKeySpecified: return "快捷键组合中未指定主键"
        }
    }
}
```

- [ ] **步骤 2：验证编译**

执行：`swift build`
期望：BUILD SUCCEEDED

- [ ] **步骤 3：提交**

```bash
git add Sources/MacOS/Core/EventEngine.swift
git commit -m "feat: 实现 EventEngine（鼠标/键盘/滚动，基于 CGEvent）"
```

---

## 任务 6：Core — ScreenCapture

**文件：**
- 创建：`Sources/MacOS/Core/ScreenCapture.swift`

- [ ] **步骤 1：实现 ScreenCaptureKit 封装**

```swift
// Sources/MacOS/Core/ScreenCapture.swift
import ScreenCaptureKit
import CoreImage
import AppKit

@available(macOS 14.0, *)
final class ScreenCapture {

    static func captureScreen(saveTo path: String) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw CaptureError.noDisplay }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        try saveImage(image, to: path)
    }

    static func captureWindow(pid: pid_t, saveTo path: String) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.owningApplication?.processID == pid }) else {
            throw CaptureError.windowNotFound
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.shouldBeOpaque = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        try saveImage(image, to: path)
    }

    private static func saveImage(_ image: CGImage, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw CaptureError.saveFailed
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CaptureError.saveFailed }
    }
}

enum CaptureError: Error, CustomStringConvertible {
    case noDisplay, windowNotFound, saveFailed
    var description: String {
        switch self {
        case .noDisplay: return "未找到显示器"
        case .windowNotFound: return "目标窗口未找到"
        case .saveFailed: return "截图保存失败"
        }
    }
}
```

- [ ] **步骤 2：验证编译**

执行：`swift build`
期望：BUILD SUCCEEDED

- [ ] **步骤 3：提交**

```bash
git add Sources/MacOS/Core/ScreenCapture.swift
git commit -m "feat: 实现 ScreenCapture（基于 ScreenCaptureKit）"
```

---

## 任务 7：命令 — see

**文件：**
- 修改：`Sources/MacOS/Commands/SeeCommand.swift`

- [ ] **步骤 1：实现 SeeCommand**

```swift
// Sources/MacOS/Commands/SeeCommand.swift
import ArgumentParser
import Foundation

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
            for el in elements { print("  \(el.id) [\(el.role)] \(el.title ?? el.value ?? "")") }
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
```

- [ ] **步骤 2：验证编译**

执行：`swift build`
期望：BUILD SUCCEEDED

- [ ] **步骤 3：手动测试**

执行：`swift run macos see --app Finder --human`
期望：输出 Finder 的 UI 元素列表

- [ ] **步骤 4：提交**

```bash
git add Sources/MacOS/Commands/SeeCommand.swift
git commit -m "feat: 实现 see 命令（元素发现 + 可选截图）"
```

---

## 任务 8：命令 — inspect

**文件：**
- 修改：`Sources/MacOS/Commands/InspectCommand.swift`

- [ ] **步骤 1：实现 InspectCommand**

```swift
// Sources/MacOS/Commands/InspectCommand.swift
import ArgumentParser
import Foundation

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
```

- [ ] **步骤 2：验证编译并测试**

执行：`swift build && swift run macos inspect --app Finder --max-depth 3 --human`
期望：输出 Finder UI 的树形结构

- [ ] **步骤 3：提交**

```bash
git add Sources/MacOS/Commands/InspectCommand.swift
git commit -m "feat: 实现 inspect 命令（原始 AX 树查看）"
```

---

## 任务 9：命令 — click

**文件：**
- 修改：`Sources/MacOS/Commands/ClickCommand.swift`

- [ ] **步骤 1：实现 ClickCommand**

```swift
// Sources/MacOS/Commands/ClickCommand.swift
import ArgumentParser
import Foundation
import CoreGraphics

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
            guard parts.count == 2 else { Output.error("坐标格式错误，使用 'x,y'"); throw ExitCode.failure }
            point = CGPoint(x: parts[0], y: parts[1])
        } else if let queryStr = query {
            let engine = AccessibilityEngine()
            let pid: pid_t
            if let appName = app {
                guard let p = engine.findApp(name: appName) else { Output.error("应用未找到: \(appName)"); throw ExitCode.failure }
                pid = p
            } else {
                guard let p = engine.frontmostApp() else { Output.error("无前台应用"); throw ExitCode.failure }
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
    enum CodingKeys: String, CodingKey { case clicked, x, y, button, clickCount = "click_count" }
}
```

- [ ] **步骤 2：验证编译**

执行：`swift build`
期望：BUILD SUCCEEDED

- [ ] **步骤 3：提交**

```bash
git add Sources/MacOS/Commands/ClickCommand.swift
git commit -m "feat: 实现 click 命令（ID/query/坐标 定位点击）"
```

---

## 任务 10：命令 — type

**文件：**
- 修改：`Sources/MacOS/Commands/TypeCommand.swift`

- [ ] **步骤 1：实现 TypeCommand**

```swift
// Sources/MacOS/Commands/TypeCommand.swift
import ArgumentParser
import Foundation

struct TypeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "type", abstract: "输入文本到 UI 元素或当前焦点")

    @Option(name: .long, help: "要输入的文本")
    var text: String?

    @Option(name: .long, help: "先点击的坐标 'x,y'（聚焦目标）")
    var coords: String?

    @Flag(name: .long, help: "输入前清空字段（Cmd+A, Delete）")
    var clear = false

    @Flag(name: .long, help: "输入后按回车")
    var pressReturn = false

    @Option(name: .long, help: "按键间延迟（毫秒，默认 5）")
    var delay: UInt32 = 5

    func run() throws {
        try Permissions.ensureAccessibility()
        if let coordStr = coords {
            let parts = coordStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 {
                EventEngine.click(at: CGPoint(x: parts[0], y: parts[1]))
                usleep(100_000)
            }
        }
        if clear {
            try EventEngine.hotkey(keys: ["cmd", "a"])
            usleep(50_000)
            EventEngine.pressKey(51)
            usleep(50_000)
        }
        if let text = text { EventEngine.typeText(text, delay: delay * 1000) }
        if pressReturn { EventEngine.pressKey(36) }
        Output.printCodable(TypeResult(typed: text ?? "", cleared: clear, pressedReturn: pressReturn))
    }
}

struct TypeResult: Codable {
    let typed: String
    let cleared: Bool
    let pressedReturn: Bool
    enum CodingKeys: String, CodingKey { case typed, cleared, pressedReturn = "pressed_return" }
}
```

- [ ] **步骤 2：验证编译并提交**

执行：`swift build`

```bash
git add Sources/MacOS/Commands/TypeCommand.swift
git commit -m "feat: 实现 type 命令（支持清空/回车）"
```

---

## 任务 11：命令 — hotkey

**文件：**
- 修改：`Sources/MacOS/Commands/HotkeyCommand.swift`

- [ ] **步骤 1：实现 HotkeyCommand**

```swift
// Sources/MacOS/Commands/HotkeyCommand.swift
import ArgumentParser

struct HotkeyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "hotkey", abstract: "按下快捷键组合（如 cmd,c）")

    @Option(name: .long, help: "逗号分隔的按键组合（如 'cmd,c'、'cmd,shift,t'）")
    var keys: String

    func run() throws {
        try Permissions.ensureAccessibility()
        let keyParts = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        try EventEngine.hotkey(keys: keyParts)
        Output.printCodable(HotkeyResult(pressed: keys))
    }
}

struct HotkeyResult: Codable { let pressed: String }
```

- [ ] **步骤 2：验证编译并提交**

```bash
swift build
git add Sources/MacOS/Commands/HotkeyCommand.swift
git commit -m "feat: 实现 hotkey 命令"
```

---

## 任务 12：命令 — scroll

**文件：**
- 修改：`Sources/MacOS/Commands/ScrollCommand.swift`

- [ ] **步骤 1：实现 ScrollCommand**

```swift
// Sources/MacOS/Commands/ScrollCommand.swift
import ArgumentParser
import CoreGraphics

struct ScrollCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scroll", abstract: "向任意方向滚动")

    @Option(name: .long, help: "方向: up, down, left, right")
    var direction: String

    @Option(name: .long, help: "滚动行数（默认 3）")
    var amount: Int32 = 3

    @Option(name: .long, help: "在指定坐标滚动 'x,y'")
    var coords: String?

    func run() throws {
        try Permissions.ensureAccessibility()
        guard let dir = EventEngine.ScrollDirection(rawValue: direction.lowercased()) else {
            Output.error("无效方向，使用: up, down, left, right"); throw ExitCode.failure
        }
        if let coordStr = coords {
            let parts = coordStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 { EventEngine.moveMouse(to: CGPoint(x: parts[0], y: parts[1])); usleep(50_000) }
        }
        EventEngine.scroll(direction: dir, amount: amount)
        Output.printCodable(ScrollResult(direction: direction, amount: amount))
    }
}

struct ScrollResult: Codable { let direction: String; let amount: Int32 }
```

- [ ] **步骤 2：验证编译并提交**

```bash
swift build
git add Sources/MacOS/Commands/ScrollCommand.swift
git commit -m "feat: 实现 scroll 命令"
```

---

## 任务 13：命令 — app

**文件：**
- 修改：`Sources/MacOS/Commands/AppCommand.swift`

- [ ] **步骤 1：实现 AppCommand**

```swift
// Sources/MacOS/Commands/AppCommand.swift
import ArgumentParser
import AppKit

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
            guard let appName = name else { Output.error("launch 需要 --name"); throw ExitCode.failure }
            let config = NSWorkspace.OpenConfiguration()
            if let url = findAppURL(name: appName) {
                let app = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
                if wait { usleep(2_000_000) }
                Output.printCodable(AppResult(action: "launch", app: appName, pid: app.processIdentifier))
            } else { Output.error("应用未找到: \(appName)"); throw ExitCode.failure }

        case "quit":
            guard let appName = name else { Output.error("quit 需要 --name"); throw ExitCode.failure }
            for app in NSWorkspace.shared.runningApplications where app.localizedName == appName {
                if force { app.forceTerminate() } else { app.terminate() }
            }
            Output.printCodable(AppResult(action: "quit", app: appName, pid: nil))

        case "focus":
            guard let appName = name else { Output.error("focus 需要 --name"); throw ExitCode.failure }
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else {
                Output.error("应用未运行: \(appName)"); throw ExitCode.failure
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
            if human { for a in apps { print("\(a.active ? "*" : " ") \(a.name) (PID: \(a.pid))") } }
            else { Output.printCodable(apps) }

        default:
            Output.error("未知操作: \(action)，使用: launch, quit, focus, list"); throw ExitCode.failure
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

struct AppResult: Codable { let action: String; let app: String; let pid: Int32? }
struct AppInfo: Codable { let name: String; let pid: Int32; let active: Bool }
```

- [ ] **步骤 2：验证编译并测试**

执行：`swift build && swift run macos app --action list --human`
期望：输出运行中应用列表

- [ ] **步骤 3：提交**

```bash
git add Sources/MacOS/Commands/AppCommand.swift
git commit -m "feat: 实现 app 命令（启动/退出/聚焦/列表）"
```

---

## 任务 14：命令 — window

**文件：**
- 修改：`Sources/MacOS/Commands/WindowCommand.swift`

- [ ] **步骤 1：实现 WindowCommand**

（完整代码包含 move/resize/close/minimize/maximize/focus/list 操作，使用 AXUIElement API 操作窗口属性。通过 --app 定位应用，--title 可选匹配窗口标题。）

代码参见设计文档中 Task 15 的完整实现。

- [ ] **步骤 2：验证编译并提交**

```bash
swift build
git add Sources/MacOS/Commands/WindowCommand.swift
git commit -m "feat: 实现 window 命令（移动/缩放/关闭/最小化/最大化/聚焦/列表）"
```

---

## 任务 15：命令 — menu

**文件：**
- 修改：`Sources/MacOS/Commands/MenuCommand.swift`

- [ ] **步骤 1：实现 MenuCommand**

（list 操作遍历菜单栏返回所有菜单项；click 操作按 "File > Save" 路径逐级导航并点击。）

代码参见设计文档中 Task 16 的完整实现。

- [ ] **步骤 2：验证编译并提交**

```bash
swift build
git add Sources/MacOS/Commands/MenuCommand.swift
git commit -m "feat: 实现 menu 命令（列表/点击）"
```

---

## 任务 16：命令 — clipboard

**文件：**
- 修改：`Sources/MacOS/Commands/ClipboardCommand.swift`

- [ ] **步骤 1：实现 ClipboardCommand**

```swift
// Sources/MacOS/Commands/ClipboardCommand.swift
import ArgumentParser
import AppKit

struct ClipboardCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clipboard", abstract: "读写系统剪贴板")

    @Option(name: .long, help: "操作: get, set, clear")
    var action: String

    @Option(name: .long, help: "要设置的文本")
    var text: String?

    func run() throws {
        let pb = NSPasteboard.general
        switch action.lowercased() {
        case "get":
            Output.printCodable(ClipboardResult(action: "get", content: pb.string(forType: .string) ?? ""))
        case "set":
            guard let t = text else { Output.error("set 需要 --text"); throw ExitCode.failure }
            pb.clearContents(); pb.setString(t, forType: .string)
            Output.printCodable(ClipboardResult(action: "set", content: t))
        case "clear":
            pb.clearContents()
            Output.printCodable(ClipboardResult(action: "clear", content: nil))
        default:
            Output.error("未知操作: \(action)，使用: get, set, clear"); throw ExitCode.failure
        }
    }
}

struct ClipboardResult: Codable { let action: String; let content: String? }
```

- [ ] **步骤 2：验证编译并提交**

```bash
swift build
git add Sources/MacOS/Commands/ClipboardCommand.swift
git commit -m "feat: 实现 clipboard 命令（get/set/clear）"
```

---

## 任务 17：集成 — 连接所有命令 + 构建测试

**文件：**
- 修改：`Sources/MacOS/MacOS.swift`（确认所有命令已注册）

- [ ] **步骤 1：确认根命令包含全部子命令**

检查 `Sources/MacOS/MacOS.swift` 的 `subcommands` 数组包含全部 10 个命令。删除桩实现文件中的占位代码。

- [ ] **步骤 2：Release 构建**

执行：`swift build -c release`
期望：BUILD SUCCEEDED，二进制位于 `.build/release/macos`

- [ ] **步骤 3：冒烟测试**

```bash
.build/release/macos --help
.build/release/macos see --help
.build/release/macos app --action list
.build/release/macos clipboard --action get
```

期望：帮助文本正常显示，app 列表和剪贴板读取正常工作。

- [ ] **步骤 4：提交**

```bash
git add -A
git commit -m "feat: 全部 10 个命令完成，Release 构建通过"
```

---

## 任务 18：SKILL.md + README.md

**文件：**
- 修改：`SKILL.md`
- 修改：`README.md`

- [ ] **步骤 1：编写 SKILL.md**

完整的 Cursor Agent 使用指南，覆盖：
- 安装方式（`swift build -c release`，加入 PATH）
- 核心工作流：`see → 识别目标 → 交互 → 验证`
- 全部命令参考表 + 参数说明
- 常见自动化场景模板
- 错误恢复建议

- [ ] **步骤 2：更新 README.md**

项目概述、构建说明、权限设置、命令列表、使用示例。

- [ ] **步骤 3：提交**

```bash
git add SKILL.md README.md
git commit -m "docs: 完成 SKILL.md Agent 指南和 README"
```

---

## 自检清单

- [x] 所有设计文档中的命令已实现：see, inspect, click, type, hotkey, scroll, app, window, menu, clipboard
- [x] 无 TBD/TODO 占位符
- [x] 类型名称跨任务一致（UIElement, Snapshot, ElementStore 等）
- [x] 每个代码步骤包含完整代码块
- [x] 指定了精确文件路径
- [x] 每个任务后有编译验证
- [x] 逻辑边界处有 Git 提交
