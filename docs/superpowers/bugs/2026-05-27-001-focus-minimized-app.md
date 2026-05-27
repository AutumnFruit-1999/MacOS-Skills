# BUG-001: 最小化应用 focus 后桌面不可见

## 状态

- **优先级：** P2
- **状态：** Open
- **发现日期：** 2026-05-27
- **影响命令：** `app --action focus`

## 复现步骤

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

## 根本原因分析

当前 `AppCommand` 的 focus 分支仅调用了 `NSRunningApplication.activate()`：

```swift
// Sources/MacOS/Commands/AppCommand.swift
case "focus":
    app.activate()
```

`activate()` 只是将应用设为活动状态（菜单栏切换），但**不会取消最小化窗口**。macOS 中最小化的窗口需要额外操作才能恢复显示：

- `NSRunningApplication.activate()` → 仅激活应用进程
- 最小化窗口需要通过 Accessibility API 设置 `kAXMinimizedAttribute = false` 来取消最小化

## 修复方案

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

## 涉及文件

| 文件 | 方法 | 说明 |
|------|------|------|
| `Sources/MacOS/Commands/AppCommand.swift` | `run()` → `case "focus"` | 需要增加取消最小化逻辑 |

## 相关知识

- `NSRunningApplication.activate()` 文档：只保证应用进程被激活（菜单栏切换），不保证窗口恢复
- `kAXMinimizedAttribute`：Accessibility 属性，`true` 表示窗口被最小化到 Dock
- 设置 `kAXMinimizedAttribute = false` 等效于双击 Dock 中的窗口缩略图

## 测试验证

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
