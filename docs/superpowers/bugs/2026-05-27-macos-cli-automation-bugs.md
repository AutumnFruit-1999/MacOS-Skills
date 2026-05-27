# macOS CLI 自动化工具 — Bug 记录

本文档记录项目开发过程中发现的所有 Bug。

---

## BUG-001: 最小化应用 focus 后桌面不可见

### 状态

- **优先级：** P2
- **状态：** Open
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
- **状态：** Open
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
