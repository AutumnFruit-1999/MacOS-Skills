# macOS CLI 自动化工具 — 测试文档

本文档提供可复现的测试步骤，验证所有命令方法正常工作。

## 前置条件

1. macOS 14+ (Sonoma)
2. 在项目根目录执行（`/Users/user/Documents/cursor/MacOS`）
3. 辅助功能权限已授予（系统设置 > 隐私与安全性 > 辅助功能）

所有命令使用 `swift run macos` 直接运行源码（无需预编译安装）。

---

## AppCommand 测试

### test_app_list — 列出运行中应用

```bash
swift run macos app --action list --human
```

**预期：** 输出所有 GUI 应用，`*` 标记活动应用，格式 `名称 (PID: xxx)`。

### test_app_list_json — JSON 格式应用列表

```bash
swift run macos app --action list
```

**预期：** JSON 数组，每项含 `name`、`pid`、`active` 字段。

### test_app_launch — 启动应用

```bash
swift run macos app --action launch --name TextEdit --wait
```

**预期：** JSON 含 `"action": "launch"`、`"pid": <number>`。TextEdit 窗口出现。

### test_app_focus — 聚焦应用

```bash
swift run macos app --action focus --name Finder
```

**预期：** Finder 成为前台应用。JSON 含 `"action": "focus"`。

### test_app_quit — 正常退出

```bash
swift run macos app --action quit --name TextEdit
```

**预期：** TextEdit 退出。JSON 含 `"action": "quit"`。

### test_app_quit_force — 强制退出

```bash
swift run macos app --action launch --name TextEdit --wait
swift run macos app --action quit --name TextEdit --force
```

**预期：** TextEdit 立即退出，无保存对话框。

### test_app_error_not_found — 错误：应用不存在

```bash
swift run macos app --action focus --name NonExistentApp123
```

**预期：** stderr 输出 `{"error": "应用未运行: NonExistentApp123"}`，退出码非 0。

---

## SeeCommand 测试

### test_see_human — 人类可读元素列表

```bash
swift run macos see --app Finder --human
```

**预期：** 输出 `应用: 访达 | 元素数: N`，后跟缩进的元素列表 `ID [角色] 标题`。

### test_see_json — JSON 格式元素列表

```bash
swift run macos see --app Finder
```

**预期：** JSON 含 `app`、`elements` 数组。每个元素含 `id`、`role`、`frame`（x/y/w/h）。

### test_see_screenshot — 附带截图

```bash
swift run macos see --app Finder --screenshot /tmp/test-see.png
```

**预期：** `/tmp/test-see.png` 生成。验证：`file /tmp/test-see.png` → `PNG image data`。

### test_see_max_depth — 自定义遍历深度

```bash
swift run macos see --app Finder --max-depth 3 --human
```

**预期：** 元素数量少于默认深度（因为只遍历 3 层）。

### test_see_error_app_not_found — 错误：应用不存在

```bash
swift run macos see --app FakeApp999
```

**预期：** stderr 输出错误 JSON，退出码非 0。

---

## InspectCommand 测试

### test_inspect_human — 人类可读 AX 树

```bash
swift run macos inspect --app Finder --max-depth 3 --human
```

**预期：** 缩进树形输出，如 `AXApplication ("访达")\n  AXWindow (...)\n    ...`。

### test_inspect_json — JSON 格式 AX 树

```bash
swift run macos inspect --app Finder --max-depth 2
```

**预期：** JSON 含 `app` 和 `tree`，tree 为嵌套结构含 `role`、`title`、`children`。

---

## ClickCommand 测试

### test_click_coords — 坐标点击

```bash
swift run macos app --action launch --name TextEdit --wait
swift run macos see --app TextEdit
# 从输出找到文本区域 frame，计算中心点
swift run macos click --coords 400,300
```

**预期：** JSON 含 `"clicked": true`、坐标信息。TextEdit 获得焦点。

### test_click_query — 文本查找点击

```bash
swift run macos click --query "最小化" --app TextEdit
```

**预期：** TextEdit 窗口最小化。JSON 含 `"clicked": true`。

### test_click_double — 双击

```bash
swift run macos click --coords 400,300 --double
```

**预期：** JSON 含 `"click_count": 2`。

### test_click_right — 右键点击

```bash
swift run macos click --coords 400,300 --right
```

**预期：** JSON 含 `"button": "right"`。弹出右键菜单。

### test_click_error_no_args — 错误：缺少参数

```bash
swift run macos click
```

**预期：** 错误提示需要 --query 或 --coords。

### test_click_error_invalid_coords — 错误：无效坐标

```bash
swift run macos click --coords abc
```

**预期：** 错误提示坐标格式不对。

---

## TypeCommand 测试

### test_type_text — 基础文本输入

```bash
swift run macos app --action launch --name TextEdit --wait
swift run macos click --coords 400,300
swift run macos type --text "Hello macOS"
```

**预期：** TextEdit 出现 "Hello macOS"。JSON 含 `"typed": "Hello macOS"`。

### test_type_clear — 清空后输入

```bash
swift run macos type --text "Replaced" --clear
```

**预期：** 原文被替换为 "Replaced"。JSON 含 `"cleared": true`。

### test_type_press_return — 输入后回车

```bash
swift run macos type --text "Line1" --press-return
```

**预期：** 输入后光标换行。JSON 含 `"pressed_return": true`。

### test_type_coords — 先聚焦坐标后输入

```bash
swift run macos type --text "Focused" --coords 400,300
```

**预期：** 先点击 (400,300) 聚焦，再输入文本。

---

## HotkeyCommand 测试

### test_hotkey_single — 单键快捷键

```bash
swift run macos hotkey --keys cmd,a
```

**预期：** 全选操作。JSON 含 `"pressed": "cmd,a"`。

### test_hotkey_multi — 多修饰键组合

```bash
swift run macos hotkey --keys cmd,shift,t
```

**预期：** 对应快捷键触发。JSON 含 `"pressed": "cmd,shift,t"`。

### test_hotkey_error_unknown_key — 错误：未知按键

```bash
swift run macos hotkey --keys cmd,xyz
```

**预期：** 错误提示 "未知按键: 'xyz'"。

---

## ScrollCommand 测试

### test_scroll_down — 向下滚动

```bash
swift run macos scroll --direction down --amount 5
```

**预期：** 当前位置向下滚动。JSON 含 `"direction": "down", "amount": 5`。

### test_scroll_up_coords — 指定坐标滚动

```bash
swift run macos scroll --direction up --amount 3 --coords 400,300
```

**预期：** 鼠标先移到 (400,300)，再向上滚动 3 行。

### test_scroll_error_invalid_direction — 错误：无效方向

```bash
swift run macos scroll --direction diagonal
```

**预期：** 错误提示使用 up/down/left/right。

---

## WindowCommand 测试

### test_window_list — 列出应用窗口

```bash
swift run macos window --action list --app Finder
```

**预期：** JSON 数组，每项含 `index`、`title`、`app`。

### test_window_move — 移动窗口

```bash
swift run macos window --action move --app TextEdit --x 200 --y 200
```

**预期：** 窗口移到 (200, 200)。JSON 含 `"success": true`。

### test_window_resize — 缩放窗口

```bash
swift run macos window --action resize --app TextEdit --width 800 --height 600
```

**预期：** 窗口变为 800x600。JSON 含 `"success": true`。

### test_window_minimize — 最小化

```bash
swift run macos window --action minimize --app TextEdit
```

**预期：** 窗口最小化到 Dock。

### test_window_close — 关闭窗口

```bash
swift run macos window --action close --app TextEdit
```

**预期：** 窗口关闭。

### test_window_focus — 聚焦窗口

```bash
swift run macos window --action focus --app TextEdit --title "未命名"
```

**预期：** 匹配标题的窗口获得焦点。

---

## MenuCommand 测试

### test_menu_list — 列出菜单项

```bash
swift run macos menu --action list --app Finder
```

**预期：** JSON 数组，每项含 `menu`（如 "File"）和 `items`（子菜单项名称数组）。

### test_menu_click — 点击菜单项

```bash
swift run macos menu --action click --app Finder --path "File > New Finder Window"
```

**预期：** 新 Finder 窗口打开。JSON 含 `"success": true`。

### test_menu_error_no_path — 错误：缺少路径

```bash
swift run macos menu --action click --app Finder
```

**预期：** 错误提示需要 --path。

---

## ClipboardCommand 测试

### test_clipboard_set — 写入剪贴板

```bash
swift run macos clipboard --action set --text "test_content_12345"
```

**预期：** JSON 含 `"action": "set", "content": "test_content_12345"`。

### test_clipboard_get — 读取剪贴板

```bash
swift run macos clipboard --action get
```

**预期：** JSON 含 `"content": "test_content_12345"`（上一步写入的内容）。

### test_clipboard_clear — 清空剪贴板

```bash
swift run macos clipboard --action clear
swift run macos clipboard --action get
```

**预期：** clear 后 get 返回 `"content": ""`。

---

## 测试汇总表

| 命令 | 测试方法 | 通过 |
|------|---------|------|
| AppCommand | test_app_list | [ ] |
| AppCommand | test_app_list_json | [ ] |
| AppCommand | test_app_launch | [ ] |
| AppCommand | test_app_focus | [ ] |
| AppCommand | test_app_quit | [ ] |
| AppCommand | test_app_quit_force | [ ] |
| AppCommand | test_app_error_not_found | [ ] |
| SeeCommand | test_see_human | [ ] |
| SeeCommand | test_see_json | [ ] |
| SeeCommand | test_see_screenshot | [ ] |
| SeeCommand | test_see_max_depth | [ ] |
| SeeCommand | test_see_error_app_not_found | [ ] |
| InspectCommand | test_inspect_human | [ ] |
| InspectCommand | test_inspect_json | [ ] |
| ClickCommand | test_click_coords | [ ] |
| ClickCommand | test_click_query | [ ] |
| ClickCommand | test_click_double | [ ] |
| ClickCommand | test_click_right | [ ] |
| ClickCommand | test_click_error_no_args | [ ] |
| ClickCommand | test_click_error_invalid_coords | [ ] |
| TypeCommand | test_type_text | [ ] |
| TypeCommand | test_type_clear | [ ] |
| TypeCommand | test_type_press_return | [ ] |
| TypeCommand | test_type_coords | [ ] |
| HotkeyCommand | test_hotkey_single | [ ] |
| HotkeyCommand | test_hotkey_multi | [ ] |
| HotkeyCommand | test_hotkey_error_unknown_key | [ ] |
| ScrollCommand | test_scroll_down | [ ] |
| ScrollCommand | test_scroll_up_coords | [ ] |
| ScrollCommand | test_scroll_error_invalid_direction | [ ] |
| WindowCommand | test_window_list | [ ] |
| WindowCommand | test_window_move | [ ] |
| WindowCommand | test_window_resize | [ ] |
| WindowCommand | test_window_minimize | [ ] |
| WindowCommand | test_window_close | [ ] |
| WindowCommand | test_window_focus | [ ] |
| MenuCommand | test_menu_list | [ ] |
| MenuCommand | test_menu_click | [ ] |
| MenuCommand | test_menu_error_no_path | [ ] |
| ClipboardCommand | test_clipboard_set | [ ] |
| ClipboardCommand | test_clipboard_get | [ ] |
| ClipboardCommand | test_clipboard_clear | [ ] |
