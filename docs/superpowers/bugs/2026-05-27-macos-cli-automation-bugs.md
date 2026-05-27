# macOS CLI 自动化工具 — Bug 记录

本文档记录项目开发过程中发现的所有 Bug。

---

## BUG-001: 最小化应用 focus 后桌面不可见

### 状态

- **优先级：** P2
- **状态：** Fixed ✅（2026-05-27）
- **修复提交：** `cb40842`
- **发现日期：** 2026-05-27
- **影响命令：** `app --action focus`

### 复现步骤

1. 将微信最小化到 Dock（点击窗口黄色最小化按钮或 Cmd+M）
2. 执行 focus 命令：
   ```bash
   swift run macos app --action focus --name 微信
   ```
3. 命令返回成功：
   ```json
   {
     "action" : "focus",
     "app" : "微信",
     "pid" : 2887
   }
   ```
4. **实际结果：** 桌面上看不到微信窗口
5. **期望结果：** 微信窗口从 Dock 恢复并显示在桌面前台

### 根本原因分析

当前 `AppCommand` 的 focus 分支仅调用了 `NSRunningApplication.activate()`：

```swift
// Sources/MacOS/Commands/AppCommand.swift
case "focus":
    app.activate()
```

`activate()` 只是将应用设为活动状态（菜单栏切换），但**不会取消最小化窗口**。macOS 中最小化的窗口需要额外操作才能恢复显示：

- `NSRunningApplication.activate()` → 仅激活应用进程
- 最小化窗口需要通过 Accessibility API 设置 `kAXMinimizedAttribute = false` 来取消最小化

### 修复方案

在 focus 操作中增加取消最小化逻辑：

```swift
case "focus":
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else {
        Output.error("应用未运行: \(appName)")
        throw ExitCode.failure
    }
    app.activate()
    // 取消所有最小化窗口
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var windowsRef: AnyObject?
    AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
    if let windows = windowsRef as? [AXUIElement] {
        for window in windows {
            var minimizedRef: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef)
            if let minimized = minimizedRef as? Bool, minimized {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFBoolean)
            }
        }
    }
```

### 涉及文件

| 文件 | 方法 | 说明 |
|------|------|------|
| `Sources/MacOS/Commands/AppCommand.swift` | `run()` → `case "focus"` | 需要增加取消最小化逻辑 |

### 相关知识

- `NSRunningApplication.activate()` 文档：只保证应用进程被激活（菜单栏切换），不保证窗口恢复
- `kAXMinimizedAttribute`：Accessibility 属性，`true` 表示窗口被最小化到 Dock
- 设置 `kAXMinimizedAttribute = false` 等效于双击 Dock 中的窗口缩略图

### 测试验证

修复后用以下步骤验证：

```bash
# 1. 先最小化微信
swift run macos window --action minimize --app 微信

# 2. 验证确实最小化了（窗口列表为空或最小化状态）
swift run macos window --action list --app 微信

# 3. 执行 focus
swift run macos app --action focus --name 微信

# 4. 验证窗口恢复显示
swift run macos see --app 微信 --human
```

---

## BUG-002: launch 通过 localizedName 查找 .app 路径失败

### 状态

- **优先级：** P1
- **状态：** Fixed ✅（2026-05-27）
- **修复提交：** `555c117`
- **发现日期：** 2026-05-27
- **影响命令：** `app --action launch`

### 复现步骤

1. 钉钉应用已安装于 `/Applications/DingTalk.app`
2. 执行 launch 命令：
   ```bash
   swift run macos app --action launch --name 钉钉 --human
   ```
3. **实际结果：**
   ```json
   {"error": "应用未找到: 钉钉"}
   ```
4. **期望结果：** 钉钉启动成功

### 根本原因分析

`findAppURL(name:)` 使用传入的 `--name` 参数直接拼接路径：

```swift
// Sources/MacOS/Commands/AppCommand.swift
private func findAppURL(name: String) -> URL? {
    for dir in ["/Applications", "/System/Applications", "/Applications/Utilities"] {
        let url = URL(fileURLWithPath: "\(dir)/\(name).app")
        if FileManager.default.fileExists(atPath: url.path) { return url }
    }
    return nil
}
```

问题在于：
- 用户传入 `--name 钉钉`（中文 localizedName）
- 实际 `.app` 文件名是 `DingTalk.app`（英文 bundle name）
- 拼接 `/Applications/钉钉.app` 路径不存在

类似问题的应用还有：微信 → `WeChat.app`、QQ → `QQ.app`（巧合同名）等。

### 修复方案

使用 `NSWorkspace` 或 Spotlight (`mdfind`) 按 `localizedName` 查找真实 URL：

```swift
private func findAppURL(name: String) -> URL? {
    // 方案 1：直接路径匹配（英文名场景）
    for dir in ["/Applications", "/System/Applications", "/Applications/Utilities"] {
        let url = URL(fileURLWithPath: "\(dir)/\(name).app")
        if FileManager.default.fileExists(atPath: url.path) { return url }
    }
    // 方案 2：通过 NSWorkspace 查找已安装应用的 bundleURL
    if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) {
        return app.bundleURL
    }
    // 方案 3：通过 Launch Services 按名称搜索
    let workspace = NSWorkspace.shared
    if let url = workspace.urlForApplication(withBundleIdentifier: "") {
        // 此 API 不支持按名称，需用 Spotlight
    }
    // 方案 4：Spotlight 查询
    // mdfind "kMDItemDisplayName == '钉钉' && kMDItemKind == 'Application'"
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
    task.arguments = ["kMDItemDisplayName == '\(name)' && kMDItemKind == 'Application'"]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8),
       let firstLine = output.split(separator: "\n").first {
        return URL(fileURLWithPath: String(firstLine))
    }
    return nil
}
```

**推荐修复策略（优先级顺序）：**
1. 先尝试直接路径匹配（已有逻辑）
2. 若应用正在运行，从 `runningApplications` 获取 `bundleURL`
3. 兜底使用 Spotlight 搜索

### 涉及文件

| 文件 | 方法 | 说明 |
|------|------|------|
| `Sources/MacOS/Commands/AppCommand.swift` | `findAppURL(name:)` | 需要支持 localizedName → bundleURL 映射 |

### 相关知识

- macOS `.app` 文件名（如 `DingTalk.app`）与 `localizedName`（如 "钉钉"）不一定相同
- `NSRunningApplication.bundleURL` 可获取正在运行应用的真实路径
- `mdfind` 是 macOS Spotlight 的命令行接口，可按 `kMDItemDisplayName` 搜索
- 影响范围：所有中文名、日文名或与 bundle name 不一致的应用

### 测试验证

修复后用以下步骤验证：

```bash
# 中文名启动
swift run macos app --action launch --name 钉钉

# 英文名启动（回归测试）
swift run macos app --action launch --name TextEdit

# 验证其他中文名应用
swift run macos app --action launch --name 微信
```

---

## BUG-003: screenshot 截图时 CGS_REQUIRE_INIT 断言崩溃

### 状态

- **优先级：** P1
- **状态：** Open
- **发现日期：** 2026-05-27
- **影响命令：** `see --screenshot`

### 复现步骤

1. 执行带截图的 see 命令：
   ```bash
   swift run macos see --app Cursor --screenshot /tmp/test-see.png
   ```
2. **实际结果：** 程序崩溃（Assertion failed）
   ```
   Assertion failed: (did_initialize), function CGS_REQUIRE_INIT, file CGInitialization.c, line 44.

   💣 Program crashed: Aborted at 0x000000018e6555b0

   Platform: arm64 macOS 26.3 (25D125)
   ```
3. **期望结果：** 截图保存到 `/tmp/test-see.png`

### 崩溃堆栈

```
Thread 2 crashed:
  0 __pthread_kill + 8 in libsystem_kernel.dylib
  1 abort + 124 in libsystem_c.dylib
  2 __assert_rtn + 284 in libsystem_c.dylib
  3 SLSGetDisplaysWithRect + 508 in SkyLight
  4 SLGetDisplaysWithRect + 72 in SkyLight
  5 -[SCContentFilter setContentsAndStreamType] + 232 in ScreenCaptureKit
  6 -[SCContentFilter initWithDesktopIndependentWindow:] + 420 in ScreenCaptureKit
  7 static ScreenCapture.captureWindow(pid:saveTo:) + 368
    → ScreenCapture.swift:24  let filter = SCContentFilter(desktopIndependentWindow: window)
  8 SeeCommand.run()
    → SeeCommand.swift:34     try await ScreenCapture.captureWindow(pid: pid, saveTo: path)
```

### 根本原因分析

`CGS_REQUIRE_INIT` 断言表示 **Core Graphics Server (CGS) 连接未初始化**。

原因是 CLI 工具作为纯命令行进程运行时，没有连接到 WindowServer（没有 GUI 事件循环）。`ScreenCaptureKit` 的 `SCContentFilter(desktopIndependentWindow:)` 内部需要通过 `SkyLight` 框架查询显示器信息，这要求进程已建立 CGS 连接。

**关键点：**
- 通过 `swift run` 或直接执行二进制时，进程没有 `NSApplication` 实例
- `ScreenCaptureKit` 依赖 WindowServer 连接来获取窗口几何信息
- 没有 CGS 连接时，`SLSGetDisplaysWithRect` 触发 `did_initialize` 断言失败

### 修复方案

在调用 ScreenCaptureKit 前确保 CGS 连接已建立：

```swift
// Sources/MacOS/Core/ScreenCapture.swift

static func captureWindow(pid: pid_t, saveTo path: String) async throws {
    // 确保 CGS 连接初始化（CLI 进程需要）
    let _ = NSApplication.shared

    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let window = content.windows.first(where: { $0.owningApplication?.processID == pid }) else {
        throw CaptureError.windowNotFound
    }
    // 使用 display + including window 替代 desktopIndependentWindow
    guard let display = content.displays.first else { throw CaptureError.noDisplay }
    let filter = SCContentFilter(display: display, including: [window])
    let config = SCStreamConfiguration()
    config.width = Int(window.frame.width)
    config.height = Int(window.frame.height)
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.shouldBeOpaque = true
    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    try saveImage(image, to: path)
}
```

**修复要点：**
1. 添加 `NSApplication.shared` 调用触发 CGS 连接初始化
2. 用 `SCContentFilter(display:including:)` 替代 `SCContentFilter(desktopIndependentWindow:)`，避免 SkyLight 内部断言
3. `captureScreen` 方法也需要同样的 `NSApplication.shared` 初始化

### 涉及文件

| 文件 | 方法 | 说明 |
|------|------|------|
| `Sources/MacOS/Core/ScreenCapture.swift` | `captureWindow(pid:saveTo:)` | 崩溃位置，第 24 行 |
| `Sources/MacOS/Core/ScreenCapture.swift` | `captureScreen(saveTo:)` | 同样可能受影响 |

### 相关知识

- `CGS_REQUIRE_INIT`：Core Graphics Server 要求进程已通过 `CGSInitialize()` 或 `NSApplication` 建立连接
- CLI 进程默认不连接 WindowServer，不像 `.app` bundle 自动初始化
- `NSApplication.shared` 的副作用：会初始化 AppKit 运行时，包括 CGS 连接
- 替代方案：使用 `CGMainDisplayID()` 也可触发 CGS 初始化
- `SCContentFilter(desktopIndependentWindow:)` 在 macOS 26 上可能比 14/15 更严格

### 测试验证

修复后用以下步骤验证：

```bash
# 窗口截图
swift run macos see --app Finder --screenshot /tmp/test-finder.png
file /tmp/test-finder.png
# 预期：PNG image data

# Electron 应用截图
swift run macos see --app Cursor --screenshot /tmp/test-cursor.png
file /tmp/test-cursor.png
# 预期：PNG image data

# 全屏截图（如果有 captureScreen 入口）
swift run macos see --screenshot /tmp/test-screen.png
file /tmp/test-screen.png
```

---

## BUG-004: 非前台应用元素发现不完整

### 状态

- **优先级：** P3
- **状态：** Open（已知限制）
- **发现日期：** 2026-05-27
- **影响命令：** `see`

### 复现步骤

1. 微信窗口不在前台（被其他应用覆盖或最小化）
2. 执行 see 命令：
   ```bash
   swift run macos see --app 微信
   ```
3. **实际结果：** 只发现 1 个元素（T1 - AXTextField）
4. 将微信切到前台后再执行相同命令：
   ```bash
   swift run macos app --action focus --name 微信
   swift run macos see --app 微信
   ```
5. **实际结果：** 发现 4 个元素（B1, B2, B3, T1）

### 根本原因分析

这是 macOS Accessibility API 的固有行为：

- 非前台窗口的 AX 树不完整（窗口控制按钮等元素未暴露）
- macOS 出于性能考虑，对后台窗口延迟加载 AX 元素
- 窗口控制按钮（关闭/最小化/缩放）只有窗口处于活跃状态时才在 AX 树中可见

### 修复方案

**方案 A（推荐）：** 在 `see` 命令中自动 focus 目标应用后再遍历

```swift
// Sources/MacOS/Commands/SeeCommand.swift
func run() async throws {
    try Permissions.ensureAccessibility()
    let engine = AccessibilityEngine(maxDepth: maxDepth)
    guard let pid = ... else { ... }
    // 自动聚焦确保 AX 树完整
    if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
        runningApp.activate()
        usleep(300_000) // 等待 AX 树更新
    }
    let elements = engine.discoverElements(pid: pid)
    ...
}
```

**方案 B：** 不自动 focus，在文档中注明 "建议先 focus 再 see" 的最佳实践

### 涉及文件

| 文件 | 方法 | 说明 |
|------|------|------|
| `Sources/MacOS/Commands/SeeCommand.swift` | `run()` | 可在发现元素前自动 focus |
| `SKILL.md` | 使用指南 | 注明最佳实践 |

### 测试验证

```bash
# 不聚焦直接 see（可能不完整）
swift run macos see --app 微信 --human

# 先聚焦再 see（完整）
swift run macos app --action focus --name 微信
swift run macos see --app 微信 --human
```
