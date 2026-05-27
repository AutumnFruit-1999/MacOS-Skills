---
name: macos-automation
description: >-
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
see（发现元素）→ 从返回的 frame 计算坐标 → 交互（click/type/hotkey）→ 再次 see 验证
```

## 命令速查

| 命令 | 用途 | 典型用法 |
|------|------|---------|
| `see` | 发现可交互元素 | `macos see --app Safari` |
| `inspect` | 查看原始 AX 树 | `macos inspect --app Safari --max-depth 3` |
| `click` | 点击 | `macos click --query "OK"` 或 `--coords 140,215` |
| `type` | 输入文本 | `macos type --text "hello" --press-return` |
| `hotkey` | 快捷键 | `macos hotkey --keys cmd,c` |
| `scroll` | 滚动 | `macos scroll --direction down --amount 5` |
| `app` | 应用管理 | `macos app --action launch --name Safari` |
| `window` | 窗口管理 | `macos window --action resize --app Safari --width 1200 --height 800` |
| `menu` | 菜单操作 | `macos menu --action click --app Finder --path "File > New Folder"` |
| `clipboard` | 剪贴板 | `macos clipboard --action get` |

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

## 错误处理

- 权限未授予：CLI 会输出错误信息并提示授权路径
- 应用/元素未找到：使用 `--human` 查看详细错误
- UI 已变化：重新执行 `see` 获取最新元素列表

## 详细参考

完整命令参数说明见 [reference.md](reference.md)。
