---
name: macos-automation
description:
  通过 Swift CLI 工具控制 macOS 桌面——发现 UI 元素、点击、输入文本、快捷键、管理应用和窗口、操作菜单和剪贴板。
  使用场景：用户要求操作 macOS 桌面、与 GUI 应用交互、自动化桌面任务、控制窗口/应用、
  或执行终端/编辑器之外的任何桌面操作。
---

# macOS 自动化 CLI

通过 Shell 调用 `macos` 命令控制 macOS 桌面。基于 Apple 原生 API（Accessibility、CGEvent、ScreenCaptureKit）。

## 前置条件

1. 已编译并加入 PATH：`swift build -c release && cp .build/release/macos /usr/local/bin/`
2. 已授权辅助功能权限：系统设置 > 隐私与安全性 > 辅助功能
3. 截图功能需额外授权：系统设置 > 隐私与安全性 > 屏幕录制

## 核心工作流

```
see/inspect（发现元素）→ 从返回的 frame 计算坐标 → 交互（click/type/hotkey）→ 再次 see 验证
若 AX 树不可见（Electron 弹框）→ ocr（视觉识别文字+坐标）→ click --coords 点击
```

## see vs inspect 使用指南

两个命令都基于 macOS Accessibility API 读取 UI 元素，但用途不同：

| | `see` | `inspect` |
|---|---|---|
| **输出** | 扁平元素列表（每个有唯一 ID） | 嵌套层级树结构 |
| **坐标** | 每个元素含 `frame` 坐标 | 仅 `--detailed` 时含坐标 |
| **适合** | 操作（点击/输入的坐标定位） | 分析（理解页面结构和层级） |

**选择策略：**
- **要点击/输入** → `see`（获取精确坐标给 `click --coords`）
- **要了解页面布局** → `inspect --detailed --human`（看层级关系）
- **找不到目标元素** → `inspect --max-depth 12 --detailed`（更深遍历树）
- **要全部页面文字** → `see --all`（不过滤角色，获取所有元素）
- **Electron 应用** → `see --web-content` 或 `see --all`（Web 视图内容）

**三种发现模式（`see` 命令）：**
```bash
macos see --app "钉钉"                # 默认：仅原生交互控件（~58 元素）
macos see --app "钉钉" --web-content   # Web内容：含 Web 视图常见角色（~128 元素）
macos see --app "钉钉" --all           # 全量：所有元素不过滤（~883 元素）
```

## 命令速查

| 命令 | 用途 | 典型用法 |
|------|------|---------|
| `see` | 发现可交互元素 | `macos see --app Safari` 或 `--web-content` 或 `--all` |
| `inspect` | 查看原始 AX 树 | `macos inspect --app Safari --max-depth 3 --detailed` |
| `click` | 点击 | `macos click --query "OK"` 或 `--coords 140,215` |
| `type` | 输入文本 | `macos type --text "hello" --press-return` |
| `hotkey` | 快捷键 | `macos hotkey --keys cmd,c` |
| `scroll` | 滚动 | `macos scroll --direction down --amount 5` |
| `app` | 应用管理 | `macos app --action launch --name Safari` |
| `window` | 窗口管理 | `macos window --action resize --app Safari --width 1200 --height 800` |
| `menu` | 菜单操作 | `macos menu --action click --app Finder --path "File > New Folder"` |
| `clipboard` | 剪贴板 | `macos clipboard --action get` |
| `ocr` | 视觉文字识别 | `macos ocr --app "钉钉"` 或 `--region "x,y,w,h"` 或 `--query "目标"` |

## 输出格式

默认输出 JSON。加 `--human` 输出人类可读文本。

`see` 返回示例：
```json
{
  "app": "Safari",
  "elements": [
    {"id": "B1", "role": "AXButton", "title": "后退", "frame": {"x": 10, "y": 52, "w": 30, "h": 30}},
    {"id": "T1", "role": "AXTextField", "title": "地址栏", "frame": {"x": 80, "y": 52, "w": 600, "h": 28}}
  ]
}
```

## 操作模式

### 坐标点击（从 see 获取坐标）

```bash
macos see --app Safari
# 从返回 JSON 中看到 T1 的 frame: {x:80, y:52, w:600, h:28}
# 计算中心: x=80+600/2=380, y=52+28/2=66
macos click --coords 380,66
macos type --text "https://example.com" --press-return
```

### Query 点击（按文本查找）

```bash
macos click --query "OK" --app Safari
```

## 常见场景

### 打开应用并导航

```bash
macos app --action launch --name Safari --wait
macos click --query "地址栏" --app Safari
macos type --text "https://example.com" --clear --press-return
```

### 跨应用复制粘贴

```bash
macos app --action focus --name TextEdit
macos hotkey --keys cmd,a
macos hotkey --keys cmd,c
macos app --action focus --name Notes
macos hotkey --keys cmd,v
```

### 窗口布局

```bash
macos window --action move --app Terminal --x 0 --y 0
macos window --action resize --app Terminal --width 960 --height 1080
macos window --action move --app Safari --x 960 --y 0
macos window --action resize --app Safari --width 960 --height 1080
```

### 菜单操作

```bash
macos menu --action list --app Finder
macos menu --action click --app Finder --path "File > New Folder"
```

### OCR 识别（Electron 弹框、AX 树不可见的内容）

```bash
# 识别应用窗口中所有文字
macos ocr --app "钉钉" --human

# 按关键词搜索特定文字的坐标
macos ocr --app "钉钉" --query "何占争"
# 返回: {"text": "何占争", "frame": {"x": 342, "y": 567, "w": 42, "h": 18}}
# 点击: macos click --coords 363,576

# 识别指定屏幕区域
macos ocr --region "600,80,400,300" --human
```

## 错误处理

- 权限未授予：CLI 会输出错误信息并提示授权路径
- 应用/元素未找到：使用 `--human` 查看详细错误
- UI 已变化：重新执行 `see` 获取最新元素列表

## Electron/Web 视图应用

对钉钉、VS Code、Cursor 等 Electron 应用，使用 `--web-content` 获取 Web 视图内部元素：

```bash
macos see --app "钉钉" --web-content
# 返回 100+ 元素（含联系人名称、消息内容等 AXStaticText）

macos inspect --app "钉钉" --max-depth 10 --detailed --human
# 输出含坐标的详细 AX 树：AXStaticText val="何占争" [342,812 44x21]
```

通过 `inspect --detailed` 在 AX 树中搜索目标元素，获取精确坐标后用 `click --coords` 交互。

## 已知限制

- **非前台应用元素不完整**：macOS Accessibility API 对非前台窗口只暴露部分元素。建议先 `app --action focus` 再 `see`
- **Electron 应用 Web 浮层不可见**：Electron 应用（钉钉、VS Code 等）中的 CSS/HTML 弹窗/浮层（如搜索面板、下拉菜单、模态对话框）在 AX 树中完全不可见。这些浮层由 Chromium 渲染引擎绘制，不会暴露为 AX 元素。**应对策略**：使用 `ocr` 命令识别弹框中的文字和坐标，再用 `click --coords` 交互
- **Electron 搜索框不接收键盘输入**：某些 Electron 应用的搜索框是 Web 渲染的 `AXStaticText`（非 `AXTextField`），占位文本通过 `kAXPlaceholderValueAttribute` 可读取，但无法通过 AX API 设置值或输入文字。**应对策略**：通过 AX 树搜索目标元素的文字内容（`inspect --max-depth 12 --detailed | grep "目标"`），获取坐标后直接点击
- **Electron 应用元素发现**：Web 视图内元素需要 `--web-content` 或 `--all` 参数才能发现；即使如此，部分深层嵌套元素可能仍不可见
- **应用名必须使用 localizedName**：中文系统下访达是"访达"非"Finder"，可通过 `app --action list` 查看正确名称

## 详细参考

完整命令参数说明见 [reference.md](reference.md)。
