# macOS CLI 自动化工具 — 优化与改进记录

本文档记录非 Bug 修复的功能优化和改进。

---

## OPT-001: focus 命令增强——支持无窗口应用唤起

- **日期：** 2026-05-27
- **提交：** `44a0cc7`
- **影响命令：** `app --action focus`

### 背景

微信等应用点击关闭按钮（红色 X）后，窗口被销毁但应用仍在 Dock 运行。此时 `focus` 命令仅调用 `activate()` 无法唤起窗口，因为：
- AX 树中无窗口（不同于最小化，最小化窗口仍在 AX 树中）
- `activate()` 只切换菜单栏，不会创建新窗口

### 优化内容

`focus` 命令现在按以下优先级处理：

```
有窗口 → 取消最小化 + AXRaiseAction + activate()
无窗口 → open -b bundleID（等同于双击 Dock 图标）+ activate()
```

### 修改文件

| 文件 | 方法 | 改动 |
|------|------|------|
| `Sources/MacOS/Commands/AppCommand.swift` | `run()` → `"focus"` | 增加无窗口分支，通过 `open -b` 唤起 |

### 验证

```bash
# 场景 1：微信点 X 关闭后唤起
swift run macos app --action focus --name 微信

# 场景 2：最小化应用恢复（BUG-001 修复）
swift run macos window --action minimize --app 文本编辑
swift run macos app --action focus --name 文本编辑

# 场景 3：正常前台应用（无变化）
swift run macos app --action focus --name 访达
```

---

## OPT-002: Web 视图内容发现——see/inspect 增强

- **日期：** 2026-05-27
- **影响命令：** `see`、`inspect`
- **影响文件：** `AccessibilityEngine.swift`、`SeeCommand.swift`、`InspectCommand.swift`

### 背景

Electron 应用（如钉钉）的 UI 大部分渲染在 `AXWebArea` 内部的 Web 视图中。原有的 `see` 命令仅收集 `isInteractive` 白名单角色（AXButton/AXTextField 等），导致 Web 视图内的 AXStaticText、AXGroup、AXImage 等元素被忽略，无法获取对话列表中的联系人名称、消息内容等关键信息。`inspect` 命令虽能遍历 AX 树，但输出仅包含 `role` 和 `title`，缺少 `frame`/`value`/`description`，导致无法定位元素的屏幕坐标和文字内容。

### 修改内容

#### 1. AccessibilityEngine.swift

| 改动项 | 说明 |
|--------|------|
| `UIElement` 新增 `description` 字段 | 存储 `kAXDescriptionAttribute`，如按钮的辅助描述 |
| `discoverElements()` 新增 `webContent: Bool` 参数 | 启用后收集 `AXWebArea` 内部的 Web 内容元素 |
| `traverse()` 新增 `insideWebArea`/`webContent` 参数 | 追踪当前是否在 Web 区域内，决定是否收集非交互元素 |
| 新增 `isWebContent(role:)` 方法 | 定义 Web 内容角色白名单：AXWebArea/AXGroup/AXStaticText/AXImage/AXLink/AXList/AXListItem/AXHeading/AXParagraph/AXTextField/AXTextArea/AXButton |
| `buildTree()` 新增 `detailed: Bool` 参数 | 启用后在树节点中包含 `value`/`description`/`frame` 属性 |
| `idPrefix` 扩展 | 新增 AXWebArea→W、AXStaticText→X、AXGroup→G、AXImage→I、AXHeading→H 前缀 |

#### 2. SeeCommand.swift

| 改动项 | 说明 |
|--------|------|
| 新增 `--web-content` 标志 | 启用 Web 视图内容发现模式 |
| `maxDepth` 自动提升 | Web 内容模式下 `maxDepth` 最小 15，`maxElements` 提升至 2000 |

#### 3. InspectCommand.swift

| 改动项 | 说明 |
|--------|------|
| 新增 `--detailed` 标志 | 在树输出中包含 frame/value/description |
| `printTree` 增强 | human 模式显示 `val="..."` `desc="..."` `[x,y wxh]` |

### 效果对比

```
# 原始模式：仅发现原生交互控件
macos see --app "钉钉"
→ ~30 个元素（大部分为 AXButton，无文字内容）

# 增强模式：包含 Web 视图内容
macos see --app "钉钉" --web-content
→ ~105 个元素（含联系人名称、消息内容、时间戳等）

# 原始 inspect：仅 role + title
macos inspect --app "钉钉" --human
→ AXStaticText

# 增强 inspect：含 value/desc/frame
macos inspect --app "钉钉" --detailed --human
→ AXStaticText val="何占争" [342,812 44x21]
```

### 验证

详见测试用例 `docs/superpowers/tests/2026-05-27-dingtalk-send-message-test-v2.md`

---

## OPT-003: 全量元素发现 + 扩展 AX 属性

- **日期：** 2026-05-27
- **影响命令：** `see`、`inspect`
- **影响文件：** `AccessibilityEngine.swift`、`SeeCommand.swift`、`InspectCommand.swift`

### 背景

OPT-002 的 `--web-content` 仍使用角色白名单过滤，某些 Electron 应用元素（如搜索框占位文本）仍然不可见。此外，许多 AX 信息存储在非标准属性中（`kAXPlaceholderValueAttribute`、`kAXHelpAttribute`、`kAXSubroleAttribute`、`AXDOMIdentifier`），之前未被读取。

### 修改内容

#### 1. AccessibilityEngine.swift

| 改动项 | 说明 |
|--------|------|
| 新增 `DiscoverMode` 枚举 | `.interactive`/`.webContent`/`.all` 三种发现模式 |
| `discoverElements(pid:mode:)` | 新增接受 `DiscoverMode` 参数的重载 |
| `.all` 模式 | 不过滤角色，收集所有元素（maxElements 提升至 5000） |
| `UIElement` 新增 5 个字段 | `placeholder`/`help`/`subrole`/`domId`/`domClass` |
| `traverse()` 读取扩展属性 | `AXPlaceholderValue`/`kAXHelpAttribute`/`kAXSubroleAttribute`/`AXDOMIdentifier`/`AXDOMClassList` |
| `buildTree()` 详细模式扩展 | 包含 `placeholder`/`help`/`subrole`/`domId` |

#### 2. SeeCommand.swift

| 改动项 | 说明 |
|--------|------|
| 新增 `--all` 标志 | 收集所有元素，不过滤角色（maxElements=5000） |

#### 3. InspectCommand.swift

| 改动项 | 说明 |
|--------|------|
| `printTree` 增强 | human 模式显示 `ph="..."` `help="..."` `sub=XXX` `#domId` |

### 效果对比

```
# 三种模式对比（以钉钉为例）
macos see --app "钉钉"               → 58 元素
macos see --app "钉钉" --web-content  → 128 元素
macos see --app "钉钉" --all          → 883 元素（480 个有文字信息）

# 搜索框占位文本（之前无法获取）
macos inspect --app "钉钉" --detailed --human | head -20
→ AXStaticText ph="搜索或提问 (⌘F)" [712,43 111x20]
```

---

## OPT-004: OCR 文字识别命令——解决 Electron 弹框不可见问题

- **日期：** 2026-05-27
- **影响命令：** 新增 `ocr`
- **影响文件：** `OCREngine.swift`（新增）、`OcrCommand.swift`（新增）、`ScreenCapture.swift`（修改）、`MacOS.swift`（修改）

### 背景

OPT-002/003 增强了 AX 树元素发现能力，但 Electron 应用（钉钉等）中的 CSS/HTML 浮层（搜索面板、下拉菜单、模态对话框）在 AX 树中完全不可见。这些浮层由 Chromium 渲染引擎绘制，macOS Accessibility API 无法感知。

### 解决方案

新增 `ocr` 命令，基于 macOS 原生 Vision 框架 + ScreenCaptureKit 实现截图文字识别，绕过 AX 树限制：

```
窗口截图（ScreenCaptureKit）→ Vision OCR 识别 → 文字 + 屏幕坐标 → 可直接用 click --coords 点击
```

### 新增文件

#### 1. OCREngine.swift

| 组件 | 说明 |
|------|------|
| `OCRTextElement` 结构体 | 存储识别结果：`text`/`confidence`/`frame`（屏幕坐标） |
| `OCREngine.recognize()` | 对 CGImage 执行 OCR，支持中英文，返回文字+坐标 |
| `OCREngine.captureRegion()` | 基于 ScreenCaptureKit 截取指定屏幕区域 |
| 坐标转换逻辑 | Vision 归一化坐标 → 图像像素坐标 → 屏幕坐标（支持 Retina 缩放） |

核心代码：
```swift
static func recognize(image: CGImage, screenRect: CGRect? = nil) throws -> [OCRTextElement] {
    let request = VNRecognizeTextRequest()
    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])
    // Vision 归一化坐标 → 屏幕坐标转换 ...
}
```

#### 2. OcrCommand.swift

| 参数 | 说明 |
|------|------|
| `--app <name>` | 对指定应用窗口 OCR（默认前台应用） |
| `--region "x,y,w,h"` | 对指定屏幕区域 OCR（与 --app 互斥） |
| `--query <text>` | 按文字内容过滤结果 |
| `--human` | 人类可读格式输出 |

#### 3. ScreenCapture.swift 修改

| 改动项 | 说明 |
|--------|------|
| 新增 `captureWindowImage()` | 返回 `(image: CGImage, frame: CGRect)` 而非直接保存文件 |
| 原有 `captureWindow(saveTo:)` | 重构为调用 `captureWindowImage()` + `saveImage()` |

#### 4. MacOS.swift 修改

| 改动项 | 说明 |
|--------|------|
| `subcommands` | 注册 `OcrCommand.self` |

### 效果验证

```bash
# 基础：识别钉钉窗口所有文字
macos ocr --app "钉钉" --human
→ 应用: 钉钉 | 识别: 113 个文字区域

# 关键：搜索弹框内容识别（AX 树完全不可见的内容）
macos click --coords 760,53   # 打开搜索弹框
macos ocr --app "钉钉" --query "综合"
→ {"text": "综合", "frame": {"x": 198, "y": 103, "w": 31, "h": 18}}
# ✅ 弹框中的文字被成功识别

# 精确搜索联系人
macos ocr --app "钉钉" --query "何占争"
→ {"text": "何占争", "frame": {"x": 342, "y": 567, "w": 42, "h": 18}}
macos click --coords 363,576  # 直接点击

# 区域识别
macos ocr --region "600,80,400,300" --human
```

### see vs ocr 对比

| | `see` / `inspect` | `ocr` |
|---|---|---|
| **原理** | Accessibility API（AX 树） | 截图 + Vision OCR |
| **速度** | ~200ms | ~900ms |
| **Electron 弹框** | ❌ 不可见 | ✅ 可识别 |
| **可交互性** | 返回 AX 元素（可 AXPress） | 返回坐标（需 click --coords） |
| **精确度** | 精确（AX 属性） | 依赖 OCR 识别率 |
| **依赖** | 辅助功能权限 | 屏幕录制权限 |

