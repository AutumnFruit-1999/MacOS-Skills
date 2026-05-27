# macOS CLI 自动化工具 — 测试文档

本文档提供可复现的测试步骤，验证所有命令方法正常工作。每个用例标注了对应的源文件和方法。

## 前置条件

1. macOS 14+ (Sonoma)
2. 在项目根目录执行（`/Users/user/Documents/cursor/MacOS`）
3. 辅助功能权限已授予（系统设置 > 隐私与安全性 > 辅助功能）

所有命令使用 `swift run macos` 直接运行源码（无需预编译安装）。

---

## AppCommand 测试

> 源文件：`Sources/MacOS/Commands/AppCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--action` | 操作类型：`launch`(启动) / `quit`(退出) / `focus`(聚焦) / `list`(列表) |
| `--name` | 目标应用名称（如 TextEdit、Finder） |
| `--force` | 强制退出（不弹保存对话框） |
| `--wait` | 等待应用启动完成（~2秒延迟） |
| `--human` | 人类可读格式输出（否则输出 JSON） |

### test_app_list

**测试方法：** `AppCommand.run()` → `case "list"` 分支

```bash
swift run macos app --action list --human
```

**预期：** 遍历 `NSWorkspace.shared.runningApplications`，输出所有 GUI 应用。

---

### test_app_launch

**测试方法：** `AppCommand.run()` → `case "launch"` 分支 + `findAppURL(name:)`

```bash
swift run macos app --action launch --name TextEdit --wait
```

**预期：** 调用 `NSWorkspace.shared.openApplication(at:configuration:)`，TextEdit 启动。

---

### test_app_focus

**测试方法：** `AppCommand.run()` → `case "focus"` 分支

```bash
swift run macos app --action focus --name Finder
```

**预期：** 调用 `NSRunningApplication.activate()`，Finder 成为前台。

---

### test_app_quit

**测试方法：** `AppCommand.run()` → `case "quit"` 分支

```bash
swift run macos app --action quit --name TextEdit
```

**预期：** 调用 `NSRunningApplication.terminate()`。

---

### test_app_quit_force

**测试方法：** `AppCommand.run()` → `case "quit"` + `--force` → `forceTerminate()`

```bash
swift run macos app --action launch --name TextEdit --wait
swift run macos app --action quit --name TextEdit --force
```

**预期：** 调用 `NSRunningApplication.forceTerminate()`，立即退出无对话框。

---

### test_app_error_not_found

**测试方法：** `AppCommand.run()` → `case "focus"` → 查找失败分支

```bash
swift run macos app --action focus --name NonExistentApp123
```

**预期：** `Output.error("应用未运行: ...")`，退出码非 0。

---

## SeeCommand 测试

> 源文件：`Sources/MacOS/Commands/SeeCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--app` | 目标应用名（省略则使用当前前台应用） |
| `--screenshot` | 截图保存路径（如 `/tmp/shot.png`） |
| `--annotate` | 在截图上标注元素 ID（搭配 --screenshot） |
| `--max-depth` | AX 树遍历最大深度（默认 10） |
| `--human` | 人类可读格式输出 |

### test_see_human

**测试方法：** `SeeCommand.run()` → `AccessibilityEngine.discoverElements(pid:)` + `human` 输出分支

```bash
swift run macos see --app Finder --human
```

**预期：** 调用 `AccessibilityEngine` 遍历 AX 树，输出扁平化的可交互元素列表。

---

### test_see_json

**测试方法：** `SeeCommand.run()` → `Output.printCodable(SeeResult(...))`

```bash
swift run macos see --app Finder
```

**预期：** JSON 输出 `SeeResult` 结构（app + elements 数组）。

---

### test_see_screenshot

**测试方法：** `SeeCommand.run()` → `ScreenCapture.captureWindow(pid:saveTo:)`

> 源文件：`Sources/MacOS/Core/ScreenCapture.swift` → `captureWindow(pid:saveTo:)`

```bash
swift run macos see --app Finder --screenshot /tmp/test-see.png
```

**验证：**
```bash
file /tmp/test-see.png
```
**预期：** `PNG image data`。

---

### test_see_max_depth

**测试方法：** `SeeCommand.run()` → `AccessibilityEngine(maxDepth:)` 初始化参数传递

```bash
swift run macos see --app Finder --max-depth 2 --human
```

**预期：** 元素数量少于默认值（遍历深度受限）。

---

## InspectCommand 测试

> 源文件：`Sources/MacOS/Commands/InspectCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--app` | 目标应用名（省略则使用当前前台应用） |
| `--max-depth` | 树输出最大深度（默认 5） |
| `--human` | 缩进树形文本输出（否则 JSON） |

### test_inspect_human

**测试方法：** `InspectCommand.run()` → `AccessibilityEngine.getTree(pid:maxDepth:)` + `printTree(_:indent:)`

```bash
swift run macos inspect --app Finder --max-depth 3 --human
```

**预期：** 递归输出树形结构，`buildTree` 方法返回嵌套字典。

---

### test_inspect_json

**测试方法：** `InspectCommand.run()` → `Output.print(result)` 序列化嵌套字典

```bash
swift run macos inspect --app Finder --max-depth 2
```

**预期：** JSON 含 `tree.role`、`tree.children[]`。

---

## ClickCommand 测试

> 源文件：`Sources/MacOS/Commands/ClickCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--coords` | 点击坐标，格式 `x,y`（屏幕绝对坐标） |
| `--query` | 按文本内容实时查找元素并点击其中心 |
| `--app` | 查找元素的应用范围（搭配 --query） |
| `--double` | 双击 |
| `--right` | 右键点击 |

### test_click_coords

**测试方法：** `ClickCommand.run()` → `coords` 分支 → `EventEngine.click(at:button:clickCount:)`

> 源文件：`Sources/MacOS/Core/EventEngine.swift` → `click(at:button:clickCount:)`

```bash
swift run macos click --coords 400,300
```

**预期：** 调用 `CGEvent` 模拟鼠标点击 (400,300)。

---

### test_click_query

**测试方法：** `ClickCommand.run()` → `query` 分支 → `AccessibilityEngine.discoverElements()` + 文本匹配 + `EventEngine.click()`

```bash
swift run macos click --query "最小化" --app Finder
```

**预期：** 遍历 Finder 元素，找到标题含 "最小化" 的按钮，计算中心坐标并点击。

---

### test_click_double

**测试方法：** `ClickCommand.run()` → `EventEngine.click(at:button:clickCount: 2)`

```bash
swift run macos click --coords 400,300 --double
```

**预期：** `clickCount = 2`，模拟双击事件。

---

### test_click_right

**测试方法：** `ClickCommand.run()` → `EventEngine.click(at:button: .right, ...)`

```bash
swift run macos click --coords 400,300 --right
```

**预期：** `CGMouseButton.right`，弹出右键菜单。

---

## TypeCommand 测试

> 源文件：`Sources/MacOS/Commands/TypeCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--text` | 要输入的文本内容 |
| `--coords` | 先点击此坐标聚焦目标（格式 `x,y`） |
| `--clear` | 输入前先清空字段（Cmd+A → Delete） |
| `--press-return` | 输入完成后按回车键 |
| `--delay` | 按键间隔（毫秒，默认 5） |

### test_type_text

**测试方法：** `TypeCommand.run()` → `EventEngine.typeText(_:delay:)`

> 源文件：`Sources/MacOS/Core/EventEngine.swift` → `typeText(_:delay:)`

```bash
swift run macos click --coords 400,300
swift run macos type --text "Hello"
```

**预期：** 逐字符通过 `CGEvent` 键盘事件输入。

---

### test_type_clear

**测试方法：** `TypeCommand.run()` → `clear` 分支 → `EventEngine.hotkey(["cmd","a"])` + `pressKey(51)`

```bash
swift run macos type --text "New" --clear
```

**预期：** 先 Cmd+A 全选，再 Delete 清空，再输入。

---

### test_type_coords

**测试方法：** `TypeCommand.run()` → `coords` 解析 → `EventEngine.click(at:)` 聚焦

```bash
swift run macos type --text "Focused" --coords 400,300
```

**预期：** 先点击 (400,300) 聚焦元素，再输入文本。

---

### test_type_press_return

**测试方法：** `TypeCommand.run()` → `pressReturn` → `EventEngine.pressKey(36)`

```bash
swift run macos type --text "Line" --press-return
```

**预期：** 输入后按回车（keyCode 36）。

---

## HotkeyCommand 测试

> 源文件：`Sources/MacOS/Commands/HotkeyCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--keys` | 逗号分隔的按键组合。修饰键：`cmd`/`shift`/`alt`(option)/`ctrl`/`fn`；主键：字母/数字/`space`/`return`/`tab`/`escape`/`f1`~`f12`/`arrow_up`等 |

### test_hotkey_single

**测试方法：** `HotkeyCommand.run()` → `EventEngine.hotkey(keys:)`

> 源文件：`Sources/MacOS/Core/EventEngine.swift` → `hotkey(keys:)` → `pressKey(_:modifiers:)`

```bash
swift run macos hotkey --keys cmd,a
```

**预期：** 解析 "cmd" 为 `.maskCommand`，"a" 查表得 keyCode 0，触发 Cmd+A。

---

### test_hotkey_multi_modifiers

**测试方法：** `EventEngine.hotkey(keys:)` → 多修饰键组合

```bash
swift run macos hotkey --keys cmd,shift,t
```

**预期：** modifiers = `.maskCommand | .maskShift`，keyCode = 17 (t)。

---

### test_hotkey_error_unknown_key

**测试方法：** `EventEngine.hotkey(keys:)` → `keyCodeMap` 查找失败 → `throw EventError.unknownKey`

> 源文件：`Sources/MacOS/Core/EventEngine.swift` → `EventError.unknownKey`

```bash
swift run macos hotkey --keys cmd,xyz
```

**预期：** 抛出 `EventError.unknownKey("xyz")`。

---

## ScrollCommand 测试

> 源文件：`Sources/MacOS/Commands/ScrollCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--direction` | 滚动方向：`up`/`down`/`left`/`right` |
| `--amount` | 滚动行数（默认 3） |
| `--coords` | 在指定坐标滚动（格式 `x,y`，先移动鼠标） |

### test_scroll_down

**测试方法：** `ScrollCommand.run()` → `EventEngine.scroll(direction: .down, amount:)`

> 源文件：`Sources/MacOS/Core/EventEngine.swift` → `scroll(direction:amount:)`

```bash
swift run macos scroll --direction down --amount 5
```

**预期：** 调用 `CGEvent(scrollWheelEvent2Source:...)` 向下滚动。

---

### test_scroll_coords

**测试方法：** `ScrollCommand.run()` → `coords` 解析 → `EventEngine.moveMouse(to:)` + `scroll()`

```bash
swift run macos scroll --direction up --amount 3 --coords 400,300
```

**预期：** 先 `moveMouse` 到 (400,300)，再 scroll。

---

## WindowCommand 测试

> 源文件：`Sources/MacOS/Commands/WindowCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--action` | 操作类型：`move`/`resize`/`close`/`minimize`/`maximize`/`focus`/`list` |
| `--app` | 目标应用名 |
| `--title` | 窗口标题（部分匹配，用于多窗口时选择） |
| `--x` / `--y` | 窗口新位置坐标（搭配 move） |
| `--width` / `--height` | 窗口新尺寸（搭配 resize） |

### test_window_list

**测试方法：** `WindowCommand.run()` → `case "list"` → `listAppWindows(appElement:appName:)`

```bash
swift run macos window --action list --app Finder
```

**预期：** 遍历 `kAXWindowsAttribute`，返回窗口信息数组。

---

### test_window_move

**测试方法：** `WindowCommand.run()` → `case "move"` → `AXValueCreate(.cgPoint)` + `AXUIElementSetAttributeValue(kAXPositionAttribute)`

```bash
swift run macos window --action move --app TextEdit --x 200 --y 200
```

**预期：** 窗口位置改变。

---

### test_window_resize

**测试方法：** `WindowCommand.run()` → `case "resize"` → `AXValueCreate(.cgSize)` + `AXUIElementSetAttributeValue(kAXSizeAttribute)`

```bash
swift run macos window --action resize --app TextEdit --width 800 --height 600
```

**预期：** 窗口大小改变。

---

### test_window_minimize

**测试方法：** `WindowCommand.run()` → `case "minimize"` → `AXUIElementSetAttributeValue(kAXMinimizedAttribute)`

```bash
swift run macos window --action minimize --app TextEdit
```

**预期：** 窗口最小化。

---

### test_window_close

**测试方法：** `WindowCommand.run()` → `case "close"` → `pressWindowButton(kAXCloseButtonAttribute)`

```bash
swift run macos window --action close --app TextEdit
```

**预期：** 关闭按钮被按下。

---

## MenuCommand 测试

> 源文件：`Sources/MacOS/Commands/MenuCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--action` | 操作类型：`list`(列出菜单) / `click`(点击菜单项) |
| `--app` | 目标应用名 |
| `--path` | 菜单路径，`>` 分隔层级（如 `"File > Save"`） |

### test_menu_list

**测试方法：** `MenuCommand.run()` → `case "list"` → `listMenuItems(appElement:)`

```bash
swift run macos menu --action list --app Finder
```

**预期：** 遍历 `kAXMenuBarAttribute` → `kAXChildrenAttribute`，返回 `[MenuItem]`。

---

### test_menu_click

**测试方法：** `MenuCommand.run()` → `case "click"` → `clickMenuItem(appElement:path:)` → `findChild(of:title:)` + `AXUIElementPerformAction(kAXPressAction)`

```bash
swift run macos menu --action click --app Finder --path "File > New Finder Window"
```

**预期：** 逐级导航菜单树并点击。

---

## ClipboardCommand 测试

> 源文件：`Sources/MacOS/Commands/ClipboardCommand.swift`

**参数说明：**
| 参数 | 含义 |
|------|------|
| `--action` | 操作类型：`get`(读取) / `set`(写入) / `clear`(清空) |
| `--text` | 要写入剪贴板的文本（搭配 `--action set`） |

### test_clipboard_set

**测试方法：** `ClipboardCommand.run()` → `case "set"` → `NSPasteboard.general.setString(_:forType:)`

```bash
swift run macos clipboard --action set --text "test_12345"
```

**预期：** 剪贴板写入成功。

---

### test_clipboard_get

**测试方法：** `ClipboardCommand.run()` → `case "get"` → `NSPasteboard.general.string(forType:)`

```bash
swift run macos clipboard --action get
```

**预期：** 返回 `"content": "test_12345"`。

---

### test_clipboard_clear

**测试方法：** `ClipboardCommand.run()` → `case "clear"` → `NSPasteboard.general.clearContents()`

```bash
swift run macos clipboard --action clear
swift run macos clipboard --action get
```

**预期：** 清空后 content 为空字符串。

---

## Permissions 测试

> 源文件：`Sources/MacOS/Core/Permissions.swift`

### test_permissions_check

**测试方法：** `Permissions.ensureAccessibility()` → `AXIsProcessTrustedWithOptions`

```bash
swift run macos see --app Finder
```

**预期：** 如已授权则正常执行；未授权则输出 `"需要辅助功能权限..."` 错误。

---

## Output 测试

> 源文件：`Sources/MacOS/Core/Output.swift`

### test_output_json

**测试方法：** `Output.printCodable(_:)` → JSON 编码

```bash
swift run macos clipboard --action get
```

**预期：** stdout 输出格式化 JSON（pretty printed + sorted keys）。

### test_output_error

**测试方法：** `Output.error(_:)` → stderr 输出

```bash
swift run macos click 2>&1
```

**预期：** stderr 包含 `{"error": "..."}` 格式。

---

## 测试汇总

| 源文件 | 测试方法 | 测试的代码路径 | 通过 |
|--------|---------|--------------|------|
| `Commands/AppCommand.swift` | test_app_list | `run()` → `"list"` 分支 | [ ] |
| `Commands/AppCommand.swift` | test_app_launch | `run()` → `"launch"` + `findAppURL()` | [ ] |
| `Commands/AppCommand.swift` | test_app_focus | `run()` → `"focus"` → `activate()` | [ ] |
| `Commands/AppCommand.swift` | test_app_quit | `run()` → `"quit"` → `terminate()` | [ ] |
| `Commands/AppCommand.swift` | test_app_quit_force | `run()` → `"quit"` + `--force` → `forceTerminate()` | [ ] |
| `Commands/AppCommand.swift` | test_app_error_not_found | `run()` → 查找失败 | [ ] |
| `Commands/SeeCommand.swift` | test_see_human | `run()` → `discoverElements()` + human 输出 | [ ] |
| `Commands/SeeCommand.swift` | test_see_json | `run()` → `Output.printCodable(SeeResult)` | [ ] |
| `Commands/SeeCommand.swift` | test_see_screenshot | `run()` → `ScreenCapture.captureWindow()` | [ ] |
| `Commands/SeeCommand.swift` | test_see_max_depth | `run()` → `AccessibilityEngine(maxDepth:)` | [ ] |
| `Commands/InspectCommand.swift` | test_inspect_human | `run()` → `getTree()` + `printTree()` | [ ] |
| `Commands/InspectCommand.swift` | test_inspect_json | `run()` → `Output.print(tree)` | [ ] |
| `Commands/ClickCommand.swift` | test_click_coords | `run()` → coords 解析 → `EventEngine.click()` | [ ] |
| `Commands/ClickCommand.swift` | test_click_query | `run()` → `discoverElements()` + 文本匹配 | [ ] |
| `Commands/ClickCommand.swift` | test_click_double | `run()` → `clickCount: 2` | [ ] |
| `Commands/ClickCommand.swift` | test_click_right | `run()` → `button: .right` | [ ] |
| `Commands/TypeCommand.swift` | test_type_text | `run()` → `EventEngine.typeText()` | [ ] |
| `Commands/TypeCommand.swift` | test_type_clear | `run()` → `hotkey(["cmd","a"])` + `pressKey(51)` | [ ] |
| `Commands/TypeCommand.swift` | test_type_coords | `run()` → coords → `click()` + `typeText()` | [ ] |
| `Commands/TypeCommand.swift` | test_type_press_return | `run()` → `pressKey(36)` | [ ] |
| `Commands/HotkeyCommand.swift` | test_hotkey_single | `run()` → `EventEngine.hotkey()` | [ ] |
| `Commands/HotkeyCommand.swift` | test_hotkey_multi | `run()` → 多修饰键解析 | [ ] |
| `Commands/HotkeyCommand.swift` | test_hotkey_error | `run()` → `EventError.unknownKey` | [ ] |
| `Commands/ScrollCommand.swift` | test_scroll_down | `run()` → `EventEngine.scroll(.down)` | [ ] |
| `Commands/ScrollCommand.swift` | test_scroll_coords | `run()` → `moveMouse()` + `scroll()` | [ ] |
| `Commands/WindowCommand.swift` | test_window_list | `run()` → `listAppWindows()` | [ ] |
| `Commands/WindowCommand.swift` | test_window_move | `run()` → `AXValueCreate(.cgPoint)` | [ ] |
| `Commands/WindowCommand.swift` | test_window_resize | `run()` → `AXValueCreate(.cgSize)` | [ ] |
| `Commands/WindowCommand.swift` | test_window_minimize | `run()` → `kAXMinimizedAttribute` | [ ] |
| `Commands/WindowCommand.swift` | test_window_close | `run()` → `pressWindowButton(kAXCloseButton)` | [ ] |
| `Commands/MenuCommand.swift` | test_menu_list | `run()` → `listMenuItems()` | [ ] |
| `Commands/MenuCommand.swift` | test_menu_click | `run()` → `clickMenuItem()` + `findChild()` | [ ] |
| `Commands/ClipboardCommand.swift` | test_clipboard_set | `run()` → `NSPasteboard.setString()` | [ ] |
| `Commands/ClipboardCommand.swift` | test_clipboard_get | `run()` → `NSPasteboard.string(forType:)` | [ ] |
| `Commands/ClipboardCommand.swift` | test_clipboard_clear | `run()` → `NSPasteboard.clearContents()` | [ ] |
| `Core/Permissions.swift` | test_permissions_check | `ensureAccessibility()` | [ ] |
| `Core/Output.swift` | test_output_json | `printCodable()` | [ ] |
| `Core/Output.swift` | test_output_error | `error()` → stderr | [ ] |
