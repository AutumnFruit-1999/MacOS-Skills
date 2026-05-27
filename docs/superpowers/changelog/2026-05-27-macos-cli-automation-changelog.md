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
