# macOS CLI Automation Tool — 设计文档

## 概述

构建一个 Swift CLI 工具，封装 Apple 原生 API（Accessibility、CGEvent、ScreenCaptureKit、NSWorkspace），让 Cursor Agent 通过 Shell 调用即可完全控制 macOS 桌面。

配套 SKILL.md 为 Agent 提供完整的使用指南，使任何安装了此工具的 Cursor 用户都能让 Agent 自动化 macOS 操作。

## 目标用户

- Cursor Agent（主要消费者）：通过 Shell 调用 CLI 工具
- 开发者（安装者）：通过 `swift build` 编译，将二进制放入 PATH

## 设计决策

### 为什么选择 Swift CLI 而非 MCP Server

| 维度 | MCP Server | Swift CLI |
|------|-----------|-----------|
| 状态管理 | 内存常驻，天然有状态 | 纯无状态，Agent 上下文即状态 |
| 架构复杂度 | 需要 MCP 协议实现 + 长连接 | 单一可执行文件，即用即走 |
| 部署 | 需要在 Cursor MCP 配置中注册 | 放入 PATH 即可 |
| 依赖 | MCP Swift SDK | 仅 ArgumentParser |
| Agent 调用方式 | 通过 MCP 工具接口 | 通过 Shell 命令 |

**结论**：CLI 方案更简单、更通用，且 Agent 自带 Shell 执行能力，不需要额外 MCP 配置。

### 为什么不用纯 osascript

- AppleScript 对 Accessibility API 的访问不完整
- 无法精确控制 CGEvent（鼠标精确坐标、按键时序）
- 无法调用 ScreenCaptureKit 进行窗口级截图
- Swift 直接调用 Apple API 性能更好、能力更全

## 架构

```
┌─────────────────────────────────────────────────┐
│  Cursor Agent                                    │
│  (通过 Shell 工具调用 CLI)                        │
└─────────────────┬───────────────────────────────┘
                  │ Shell: macos <command> [args]
                  ▼
┌─────────────────────────────────────────────────┐
│  macos CLI (Swift ArgumentParser)                │
│                                                  │
│  Commands:                                       │
│  ├── see       (元素发现 + 可选截图)                │
│  ├── inspect   (原始 AX 树结构)                    │
│  ├── click     (点击)                            │
│  ├── type      (输入文本)                         │
│  ├── hotkey    (快捷键)                           │
│  ├── scroll    (滚动)                            │
│  ├── app       (应用管理)                         │
│  ├── window    (窗口管理)                         │
│  ├── menu      (菜单操作)                         │
│  └── clipboard (剪贴板)                           │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│  Core Engines                                    │
│                                                  │
│  ├── AccessibilityEngine (AXUIElement API)       │
│  ├── EventEngine (CGEvent API)                   │
│  └── ScreenCapture (ScreenCaptureKit)            │
└─────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│  macOS System APIs                               │
│  AXUIElement · CGEvent · ScreenCaptureKit        │
│  NSWorkspace · NSPasteboard                      │
└─────────────────────────────────────────────────┘
```

## CLI 接口设计

### 全局选项

```
macos [--json | --human] <command> [options]
```

- `--json`（默认）：输出 JSON 格式，方便 Agent 解析
- `--human`：输出人类可读文本

### 命令列表

#### `macos see` — 元素发现（可选截图）

```bash
macos see [--app <name>] [--screenshot [<path>]] [--annotate] [--max-depth <n>]
```

- `--app`：目标应用名（省略则检查前台应用）
- `--screenshot`：附带截图（可选指定保存路径，默认 /tmp/macos-screenshot.png）
- `--annotate`：在截图上标注元素 ID（需配合 --screenshot）
- `--max-depth`：AX 树遍历最大深度（默认 10）

默认输出 JSON（仅元素列表）：
```json
{
  "app": "Safari",
  "elements": [
    {"id": "B1", "role": "button", "title": "OK", "frame": {"x": 100, "y": 200, "w": 80, "h": 30}},
    {"id": "T1", "role": "textField", "value": "", "frame": {"x": 50, "y": 100, "w": 200, "h": 24}}
  ]
}
```

带 --screenshot 时额外返回截图路径：
```json
{
  "screenshot": "/tmp/macos-screenshot.png",
  "app": "Safari",
  "elements": [...]
}
```

注意：元素 ID（B1, T1）仅用于人类可读标识，Agent 应使用 frame 坐标或 --query 进行后续操作。

#### `macos inspect` — 原始 AX 树结构

```bash
macos inspect [--app <name>] [--max-depth <n>]
```

用于调试和探索 UI 结构，返回完整的 AX 树层级（非扁平化列表）：
```json
{
  "app": "Safari",
  "tree": {
    "role": "AXApplication",
    "title": "Safari",
    "children": [
      {
        "role": "AXWindow",
        "title": "新标签页",
        "children": [
          {"role": "AXToolbar", "children": [
            {"role": "AXButton", "title": "后退"},
            {"role": "AXTextField", "title": "地址栏"}
          ]}
        ]
      }
    ]
  }
}
```

与 `see` 的区别：`see` 返回扁平化的可交互元素列表（带 ID），`inspect` 返回完整树结构（用于理解 UI 层级）。

#### `macos click` — 点击

```bash
macos click [--query <text>] [--coords <x,y>] [--app <name>] [--double] [--right]
```

- `--query`：按文本内容实时查找元素并点击（内部自动计算中心坐标）
- `--coords`：按坐标点击（Agent 从 `see` 返回的 frame 计算得到）
- `--app`：目标应用名（用于 query 搜索范围）
- `--double`：双击
- `--right`：右键点击

#### `macos type` — 输入文本

```bash
macos type --text <string> [--coords <x,y>] [--clear] [--press-return] [--delay <ms>]
```

- `--text`：要输入的文本
- `--coords`：先点击此坐标聚焦（格式 `x,y`）
- `--clear`：输入前清空字段（Cmd+A, Delete）
- `--press-return`：输入后按回车
- `--delay`：按键间延迟（毫秒），默认 5

#### `macos hotkey` — 快捷键

```bash
macos hotkey --keys <key_combo>
```

- `--keys`：逗号分隔的按键组合，如 `cmd,c` / `cmd,shift,t`
- 支持的修饰键：cmd, shift, alt/option, ctrl, fn
- 支持的按键：a-z, 0-9, space, return, tab, escape, delete, f1-f12, arrow_up/down/left/right

#### `macos scroll` — 滚动

```bash
macos scroll --direction <up|down|left|right> [--amount <n>] [--coords <x,y>]
```

#### `macos app` — 应用管理

```bash
macos app --action <launch|quit|focus|list> [--name <app_name>]
          [--force] [--wait]
```

- `launch`：启动应用
- `quit`：退出应用（--force 强制退出）
- `focus`：聚焦到应用
- `list`：列出所有运行中的应用

#### `macos window` — 窗口管理

```bash
macos window --action <move|resize|close|minimize|maximize|focus|list>
             [--app <name>] [--title <window_title>]
             [--x <n>] [--y <n>] [--width <n>] [--height <n>]
```

#### `macos menu` — 菜单操作

```bash
macos menu --action <list|click> --app <name> [--path <"File > Save">]
```

- `list`：列出应用的所有菜单项
- `click`：点击指定菜单路径

#### `macos clipboard` — 剪贴板

```bash
macos clipboard --action <get|set|clear> [--text <string>]
```

## 无状态设计

CLI 采用纯无状态设计，不使用 snapshot 文件。原因：

- Agent 的对话上下文本身就是状态管理——`see` 返回的 JSON 自动留在 Agent 上下文中
- Agent 后续操作时直接从上下文中提取坐标（frame → 计算中心点）或使用 `--query` 实时搜索
- 无文件 I/O 开销，架构更简单可靠

## 权限要求

- **辅助功能权限**：系统设置 > 隐私与安全 > 辅助功能（必须）
- **屏幕录制权限**：系统设置 > 隐私与安全 > 屏幕录制（`see` 命令需要）

CLI 首次运行时检测权限状态，未授权时输出友好提示并退出。

## 项目结构

```
MacOS/
├── SKILL.md                          # Agent 使用指南（Cursor Skill 规范）
├── reference.md                      # 详细命令参考（渐进式披露）
├── README.md                         # 项目说明 + 安装指南
├── Package.swift                     # SPM 配置（依赖 ArgumentParser）
├── Sources/
│   └── MacOS/
│       ├── MacOS.swift               # CLI 入口 + 命令注册
│       ├── Core/
│       │   ├── AccessibilityEngine.swift   # AXUIElement 封装
│       │   ├── EventEngine.swift           # CGEvent 封装
│       │   ├── ScreenCapture.swift         # ScreenCaptureKit 封装
│       │   ├── Permissions.swift           # 权限检查
│       │   └── Output.swift               # JSON/Human 输出格式化
│       └── Commands/
│           ├── SeeCommand.swift
│           ├── InspectCommand.swift
│           ├── ClickCommand.swift
│           ├── TypeCommand.swift
│           ├── HotkeyCommand.swift
│           ├── ScrollCommand.swift
│           ├── AppCommand.swift
│           ├── WindowCommand.swift
│           ├── MenuCommand.swift
│           └── ClipboardCommand.swift
└── docs/superpowers/
    ├── specs/                        # 设计文档
    └── plans/                        # 实现计划
```

## 技术选型

| 组件 | 技术 | 理由 |
|------|------|------|
| CLI 框架 | swift-argument-parser | Apple 官方，成熟稳定 |
| UI 自动化 | AXUIElement (C API) | macOS 唯一官方 UI 自动化接口 |
| 输入模拟 | CGEvent | 系统级事件注入，全应用生效 |
| 截图 | ScreenCaptureKit | 窗口级精确截图，支持排除阴影 |
| 应用管理 | NSWorkspace + NSRunningApplication | 标准 AppKit API |
| 剪贴板 | NSPasteboard | 标准 AppKit API |
| 最低系统要求 | macOS 14 (Sonoma) | ScreenCaptureKit API 稳定版 |

## SKILL.md 设计要点

Skill 文档需要教会 Agent：
1. 工具的安装/编译方式
2. 核心工作流模式：`see → 识别目标 → 交互 → 验证`
3. 每个命令的完整参数说明
4. 常见自动化场景模板（打开应用、填表单、跨应用复制等）
5. 错误处理和权限问题的解决方式

## 实现优先级

1. **P0（核心）**：Package.swift, main.swift, AccessibilityEngine, EventEngine
2. **P1（基础命令）**：see, click, type, hotkey, app
3. **P2（完善命令）**：window, scroll, menu, clipboard, inspect
4. **P3（文档）**：SKILL.md, README.md
5. **P4（增强）**：annotate 截图标注、query 模糊匹配、error recovery 提示

## 部署与使用

### 编译安装

```bash
# 克隆仓库
git clone <repo-url> && cd MacOS

# 编译 Release 二进制
swift build -c release

# 安装到系统 PATH（二选一）
cp .build/release/macos /usr/local/bin/macos
# 或
ln -s $(pwd)/.build/release/macos /usr/local/bin/macos
```

### 权限配置（首次）

1. 打开系统设置 > 隐私与安全性 > 辅助功能
2. 添加终端应用（Terminal.app 或 iTerm 或 Cursor）
3. （可选）屏幕录制权限 —— 仅 `see --screenshot` 需要

### 作为 Cursor Skill 注册

```bash
# 方式一：符号链接（推荐，更新方便）
ln -s $(pwd) ~/.cursor/skills/macos-automation

# 方式二：复制到项目级 skill
cp -r $(pwd) .cursor/skills/macos-automation
```

注册后，Agent 在需要操作 macOS 桌面时会自动加载 SKILL.md。

### 验证安装

```bash
# 检查命令可用
macos --help

# 测试辅助功能权限
macos see --app Finder --human

# 测试基础操作
macos app --action list --human
macos clipboard --action get
```

### 更新

```bash
cd MacOS && git pull && swift build -c release
# 如果使用了 cp 安装，需重新复制
cp .build/release/macos /usr/local/bin/macos
```

## 风险与限制

1. **权限授予**：首次使用需手动授权辅助功能和屏幕录制，无法自动化
2. **SIP 限制**：无法操作某些系统进程（如 loginwindow）
3. **UI 变化**：执行操作后 UI 可能改变，Agent 需重新 `see` 获取最新元素
4. **CGEvent 限制**：需要进程有 kTCCServiceAccessibility 权限
5. **ScreenCaptureKit 权限**：首次截图会触发系统权限弹窗
