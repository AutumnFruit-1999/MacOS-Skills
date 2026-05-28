# macOS CLI 自动化工具 — 2026-05-28 优化与改进记录

本文档记录 2026-05-28 在钉钉文件发送自动化实践中发现的优化需求。

---

## OPT-005: clipboard 命令增加文件类型支持（已完成）

- **日期：** 2026-05-28
- **状态：** 已完成
- **优先级：** 高——文件传递是桌面自动化的核心场景
- **影响命令：** `clipboard`
- **影响文件：** `ClipboardCommand.swift`

### 背景

当前 `clipboard --action set` 仅支持 `--text` 参数设置纯文本到剪贴板。在实际桌面自动化场景中（如向钉钉发送文件），需要将文件引用写入剪贴板后粘贴到目标应用。目前只能通过 `osascript -e 'set the clipboard to (POSIX file "...")'` 绕行，不属于 `macos` CLI 的能力范围。

### 设计原则

**复制粘贴优先，鼠标点击兜底。** 文件传递应优先使用剪贴板复制 + Cmd+V 粘贴，因为：
1. 不依赖 UI 布局和图标识别，稳定性高
2. 跨应用通用，无需针对每个应用适配文件按钮位置
3. 大部分 IM 应用（钉钉、微信、飞书等）都支持粘贴文件

仅当目标应用不支持粘贴文件时，才回退到鼠标点击文件按钮 + 文件选择器的方式。

### 优化方案

为 `clipboard --action set` 新增 `--file <path>` 参数，使用 `NSPasteboard` 的 `writeObjects` 方法将 `NSURL` 文件引用写入系统剪贴板。

#### ClipboardCommand.swift 修改

| 改动项 | 说明 |
|--------|------|
| 新增 `--file` 参数 | `@Option(help: "要复制到剪贴板的文件路径") var file: String?` |
| `set` action 增加文件分支 | `--file` 和 `--text` 互斥；`--file` 时验证文件存在，将 `NSURL` 写入 `NSPasteboard` |
| 输出增强 | 成功时返回 `{"action":"set","type":"file","path":"...","size":1234}` |

#### 核心实现

```swift
if let filePath = file {
    let url = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: filePath) else {
        throw ValidationError("文件不存在: \(filePath)")
    }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([url as NSURL])
}
```

### 验证

```bash
# 复制文件到剪贴板
macos clipboard --action set --file "/Users/user/Desktop/file.xlsx"

# 验证剪贴板内容
macos clipboard --action get
# → {"type":"file","path":"/Users/user/Desktop/file.xlsx"}

# 配合钉钉发送
macos clipboard --action set --file "/path/to/file.xlsx"
macos app --action focus --name "钉钉"
macos hotkey --keys cmd,v
# → 触发钉钉文件发送确认弹窗
```

---

## OPT-006: ocr 命令支持 --app 与 --region 同时使用（已完成）

- **日期：** 2026-05-28
- **状态：** 已完成
- **优先级：** 中——改善 OCR 使用体验，减少手动坐标计算
- **影响命令：** `ocr`
- **影响文件：** `OcrCommand.swift`、`OCREngine.swift`

### 背景

当前 `ocr` 命令的 `--app` 和 `--region` 参数互斥：`--app` 截取整个应用窗口，`--region` 截取屏幕指定区域。在实际使用中，用户常需要对某个应用窗口的特定区域做 OCR（如仅识别工具栏或标题栏），目前必须手动计算屏幕绝对坐标传给 `--region`，不够直观。

### 设计原则

此优化属于辅助能力增强。当"复制粘贴优先"策略不适用（如需要识别 UI 状态、验证操作结果），精确的区域 OCR 可以减少不必要的全窗口扫描，提高识别速度和准确率。

### 优化方案

当 `--app` 和 `--region` 同时提供时，执行以下流程：

```
1. 通过 ScreenCaptureKit 截取应用窗口图像 → 获得 (image, windowFrame)
2. 将 --region 坐标解释为窗口内相对坐标（而非屏幕绝对坐标）
3. 裁剪图像到指定区域
4. 对裁剪后的图像执行 OCR
5. 将 OCR 结果坐标转换回屏幕绝对坐标（加上 windowFrame 偏移）
```

#### OcrCommand.swift 修改

| 改动项 | 说明 |
|--------|------|
| 移除互斥校验 | 不再报错 `--app 和 --region 不能同时使用` |
| 新增组合逻辑 | 同时提供时，`--region` 为窗口内相对坐标 |
| 文档更新 | 说明两种 `--region` 含义：单独使用=屏幕绝对坐标，配合 `--app`=窗口相对坐标 |

### 验证

```bash
# 当前行为（报错）
macos ocr --app "钉钉" --region "0,0,400,100"
# → {"error": "--app 和 --region 不能同时使用"}

# 优化后（识别钉钉窗口左上角 400x100 区域）
macos ocr --app "钉钉" --region "0,0,400,100"
# → 仅返回该区域内的 OCR 结果，坐标为屏幕绝对坐标

# 等效于当前的手动计算方式
macos ocr --region "602,80,400,100"   # 需要先知道窗口位置
```

---

## OPT-007: 图标按钮识别能力说明与推荐交互策略（已知限制）

- **日期：** 2026-05-28
- **状态：** 已知限制，记录推荐策略和解决思路
- **影响命令：** `see`、`ocr`、`clipboard`

### 背景

在钉钉等 Electron 应用中，底部工具栏使用纯图形图标（SVG/PNG），无文字标签、无 AX `title`/`description` 属性。`see` 命令返回的 AXButton 没有名称，`ocr` 基于 Vision 文字识别也无法识别图标含义，导致无法自动判断哪个按钮是"发送文件"、"表情"、"截图"等功能。

### 推荐交互策略：复制粘贴优先，鼠标点击兜底

在遇到无法识别的 UI 图标按钮时，**应优先尝试通过剪贴板复制+粘贴来完成操作**，而非尝试定位和点击特定图标按钮。仅当复制粘贴不可行时，才回退到鼠标定位+点击操作。

#### 策略优先级

```
优先级 1（推荐）：剪贴板复制 + Cmd+V 粘贴
  → 适用：文件发送、图片发送、文本传递
  → 优势：不依赖 UI 布局、无需图标识别、跨应用通用
  → 示例：macos clipboard --action set --file "xxx" && macos hotkey --keys cmd,v

优先级 2（兜底）：鼠标定位 + 点击操作
  → 适用：复制粘贴不支持的场景（如需要点击特定功能按钮）
  → 方式：截图辨认图标 → 记录坐标 → click --coords
  → 劣势：依赖固定布局，应用更新后可能失效
```

#### 各场景推荐方式

| 场景 | 推荐方式 | 说明 |
|------|----------|------|
| 发送文件 | `clipboard --file` + `Cmd+V` | 大部分 IM 支持粘贴文件 |
| 发送图片 | `clipboard --file` + `Cmd+V` | 同上 |
| 发送文本 | `clipboard --text` + `Cmd+V` 或 `type --text` | 优先 type，复杂文本用 clipboard |
| 截图操作 | 快捷键（如 `Cmd+Shift+A`） | 不同应用快捷键不同 |
| 打开表情 | `click --coords` + 截图定位 | 无快捷键替代 |

### 实际表现

```bash
# see 返回无标签按钮
macos see --app "钉钉" --human
# → B37 [AXButton]    ← 无 title、无 description
# → B38 [AXButton]
# → B39 [AXButton]

# OCR 无法识别图标
macos ocr --region "610,820,300,50"
# → 识别: 0 个文字区域
```

### 钉钉底部工具栏图标映射（实际确认）

从左到右依次为：

| 序号 | 图标 | 功能 | 说明 |
|------|------|------|------|
| 1 | 😊 | 表情 | 打开表情选择器 |
| 2 | 👍▾ | 快捷表情 | 点赞/反应，有下拉 |
| 3 | Aa | 字体 | 文字格式设置 |
| 4 | ✂️▾ | 截图 | 截图工具，有下拉 |
| 5 | 📤 | 发送文件 | 打开文件选择器 |
| 6 | ⊕ | 更多 | 更多工具 |

### 潜在改进方向（不纳入当前开发计划）

1. **增强 AX 属性读取**：尝试读取 `kAXRoleDescriptionAttribute`、自定义属性
2. **hover tooltip 采集**：模拟鼠标悬停获取 tooltip 文字（需 CGEvent + 等待时间）
3. **模板匹配**：预存常见应用图标模板，通过图像相似度匹配（复杂度高）
4. **多模态 AI**：截图发给 Vision LLM 识别图标含义（超出 CLI 工具范畴，可由 Agent 层面解决）
