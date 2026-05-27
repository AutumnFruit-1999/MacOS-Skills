# macOS Automation CLI

让 Cursor Agent 通过 Shell 命令控制 macOS 桌面的 Swift CLI 工具。

基于 Apple 原生 API：Accessibility (AXUIElement)、CGEvent、ScreenCaptureKit、NSWorkspace。

## 功能

- **元素发现** — 遍历 UI 元素，返回可交互组件列表
- **鼠标操作** — 坐标点击、文本查找点击、双击、右键
- **键盘操作** — 输入文本、快捷键组合
- **应用管理** — 启动、退出、聚焦、列出应用
- **窗口管理** — 移动、缩放、关闭、最大化、最小化
- **菜单操作** — 列出并点击菜单项
- **剪贴板** — 读写系统剪贴板
- **截图** — 窗口级截图（ScreenCaptureKit）

## 系统要求

- macOS 14 (Sonoma) 或更高
- Swift 6.0+ (Xcode 16+)
- 辅助功能权限
- 屏幕录制权限（截图功能）

## 安装

```bash
git clone <repo-url> && cd MacOS
swift build -c release
cp .build/release/macos /usr/local/bin/
```

## 权限设置

首次运行会提示授权：

1. **辅助功能**：系统设置 > 隐私与安全性 > 辅助功能 > 添加终端应用
2. **屏幕录制**（可选）：系统设置 > 隐私与安全性 > 屏幕录制

## 快速上手

```bash
# 查看帮助
macos --help

# 发现 Finder 的 UI 元素
macos see --app Finder --human

# 点击按钮
macos click --query "OK" --app Finder

# 输入文本
macos type --text "Hello World"

# 快捷键 Cmd+C
macos hotkey --keys cmd,c

# 列出运行中的应用
macos app --action list --human
```

## 作为 Cursor Skill 使用

将此仓库链接到 Cursor Skills 目录：

```bash
ln -s $(pwd) ~/.cursor/skills/macos-automation
```

Agent 将自动在需要操作 macOS 桌面时加载此技能。

## 项目结构

```
├── SKILL.md              # Agent 使用指南（Cursor Skill）
├── reference.md          # 完整命令参考
├── README.md             # 本文件
├── Package.swift         # Swift Package Manager 配置
├── Sources/MacOS/
│   ├── MacOS.swift       # CLI 入口 + 命令注册
│   ├── Core/             # 系统 API 封装
│   │   ├── AccessibilityEngine.swift
│   │   ├── EventEngine.swift
│   │   ├── ScreenCapture.swift
│   │   ├── Permissions.swift
│   │   └── Output.swift
│   └── Commands/         # 子命令实现
│       ├── SeeCommand.swift
│       ├── InspectCommand.swift
│       ├── ClickCommand.swift
│       ├── TypeCommand.swift
│       ├── HotkeyCommand.swift
│       ├── ScrollCommand.swift
│       ├── AppCommand.swift
│       ├── WindowCommand.swift
│       ├── MenuCommand.swift
│       └── ClipboardCommand.swift
└── docs/                 # 设计文档
```

## 许可证

MIT
