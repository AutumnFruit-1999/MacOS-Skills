# macOS CLI 自动化工具 — 测试文档

本文档提供可复现的测试步骤，验证所有 10 个命令正常工作。

## 前置条件

1. macOS 14+ (Sonoma)
2. 已编译：`swift build -c release`
3. 二进制可用：`.build/release/macos` 或已加入 PATH
4. 辅助功能权限已授予（系统设置 > 隐私与安全性 > 辅助功能）
5. Finder 应用正在运行

以下用 `macos` 代表 CLI 路径（如未加入 PATH 请替换为 `.build/release/macos`）。

---

## 测试 1：帮助信息

```bash
macos --help
```

**预期：** 显示所有 10 个子命令及描述。

```bash
macos see --help
```

**预期：** 显示 see 命令的 --app、--screenshot、--max-depth 等参数说明。

---

## 测试 2：app — 应用列表

```bash
macos app --action list --human
```

**预期：** 输出所有运行中的 GUI 应用列表，格式如：
```
  访达 (PID: 519)
* Cursor (PID: 25539)
```

`*` 标记当前活动应用。

---

## 测试 3：app — 启动应用

```bash
macos app --action launch --name TextEdit --wait
```

**预期：** 输出 JSON 包含 `"action": "launch"` 和 PID。TextEdit 窗口出现。

---

## 测试 4：see — 元素发现

```bash
macos see --app TextEdit --human
```

**预期：** 输出 TextEdit 的可交互元素列表，如：
```
应用: TextEdit | 元素数: 15
  B1 [AXButton] 关闭
  B2 [AXButton] 最小化
  T1 [AXTextArea]
```

---

## 测试 5：see — JSON 输出

```bash
macos see --app TextEdit
```

**预期：** 输出 JSON 格式，包含 `app`、`elements` 数组，每个元素有 `id`、`role`、`title`、`frame`。

---

## 测试 6：see — 截图

```bash
macos see --app TextEdit --screenshot /tmp/test-screenshot.png
```

**预期：** `/tmp/test-screenshot.png` 文件生成，可用预览打开。

验证：
```bash
file /tmp/test-screenshot.png
```
输出应包含 `PNG image data`。

---

## 测试 7：inspect — AX 树结构

```bash
macos inspect --app TextEdit --max-depth 3 --human
```

**预期：** 输出缩进的树形结构：
```
AXApplication ("TextEdit")
  AXWindow ("未命名")
    AXToolbar
      AXButton ("关闭")
      ...
```

---

## 测试 8：click — 坐标点击

先获取元素坐标：
```bash
macos see --app TextEdit
```

从输出中找到文本区域的 frame（如 `{"x": 50, "y": 100, "w": 600, "h": 400}`），计算中心点后点击：

```bash
macos click --coords 350,300
```

**预期：** 输出 `"clicked": true`，TextEdit 文本区域获得焦点。

---

## 测试 9：click — 文本查找点击

```bash
macos click --query "关闭" --app TextEdit
```

**预期：** TextEdit 关闭按钮被点击（窗口可能关闭或弹出保存对话框）。

---

## 测试 10：type — 输入文本

先确保 TextEdit 打开（若已关闭，重新启动）：
```bash
macos app --action launch --name TextEdit --wait
macos click --coords 350,300
macos type --text "Hello, macOS Automation!"
```

**预期：** TextEdit 中出现 "Hello, macOS Automation!" 文本。

---

## 测试 11：type — 清空并输入

```bash
macos type --text "New content" --clear --press-return
```

**预期：** 先清空原有内容，输入 "New content"，然后换行。

---

## 测试 12：hotkey — 快捷键

```bash
macos hotkey --keys cmd,a
```

**预期：** 全选操作（TextEdit 中文本全部选中）。

```bash
macos hotkey --keys cmd,c
```

**预期：** 复制到剪贴板。

---

## 测试 13：clipboard — 读取

```bash
macos clipboard --action get
```

**预期：** 输出刚复制的文本内容。

---

## 测试 14：clipboard — 写入

```bash
macos clipboard --action set --text "测试剪贴板内容"
macos clipboard --action get
```

**预期：** 第二次输出 `"content": "测试剪贴板内容"`。

---

## 测试 15：clipboard — 清空

```bash
macos clipboard --action clear
macos clipboard --action get
```

**预期：** 清空后 content 为空字符串。

---

## 测试 16：scroll — 滚动

```bash
macos scroll --direction down --amount 5
```

**预期：** 当前鼠标位置向下滚动 5 行。

```bash
macos scroll --direction up --amount 3 --coords 400,300
```

**预期：** 鼠标移动到 (400,300) 后向上滚动 3 行。

---

## 测试 17：window — 移动窗口

```bash
macos window --action move --app TextEdit --x 100 --y 100
```

**预期：** TextEdit 窗口移动到屏幕 (100, 100) 位置。

---

## 测试 18：window — 缩放窗口

```bash
macos window --action resize --app TextEdit --width 800 --height 600
```

**预期：** TextEdit 窗口大小变为 800x600。

---

## 测试 19：window — 列出窗口

```bash
macos window --action list --app TextEdit
```

**预期：** 输出 JSON 数组，包含 TextEdit 的窗口信息（index、title、app）。

---

## 测试 20：menu — 列出菜单

```bash
macos menu --action list --app TextEdit
```

**预期：** 输出 JSON 数组，每项包含 `menu`（菜单名）和 `items`（子菜单项数组）。

---

## 测试 21：menu — 点击菜单

```bash
macos menu --action click --app TextEdit --path "Format > Font > Bold"
```

**预期：** 文本切换为粗体（或输出成功 JSON）。

---

## 测试 22：app — 聚焦应用

```bash
macos app --action focus --name Finder
```

**预期：** Finder 成为前台应用。

---

## 测试 23：app — 退出应用

```bash
macos app --action quit --name TextEdit
```

**预期：** TextEdit 退出（可能弹出保存对话框）。

```bash
macos app --action quit --name TextEdit --force
```

**预期：** TextEdit 强制退出，不弹出对话框。

---

## 测试 24：window — 最小化/关闭

```bash
macos app --action launch --name TextEdit --wait
macos window --action minimize --app TextEdit
```

**预期：** TextEdit 窗口最小化到 Dock。

```bash
macos window --action close --app TextEdit
```

**预期：** TextEdit 窗口关闭。

---

## 错误场景测试

### 应用不存在

```bash
macos see --app NonExistentApp
```

**预期：** stderr 输出错误 JSON：`{"error": "应用未找到: NonExistentApp"}`，退出码非 0。

### 无效坐标格式

```bash
macos click --coords abc
```

**预期：** 错误提示坐标格式不对。

### 缺少必需参数

```bash
macos click
```

**预期：** 错误提示需要指定 --query 或 --coords。

### 未知快捷键

```bash
macos hotkey --keys cmd,xyz
```

**预期：** 错误提示 "未知按键: 'xyz'"。

---

## 测试汇总

| # | 命令 | 测试项 | 通过 |
|---|------|--------|------|
| 1 | --help | 帮助信息 | [ ] |
| 2 | app list | 应用列表 | [ ] |
| 3 | app launch | 启动应用 | [ ] |
| 4 | see --human | 元素发现（人类格式） | [ ] |
| 5 | see (json) | 元素发现（JSON） | [ ] |
| 6 | see --screenshot | 截图 | [ ] |
| 7 | inspect | AX 树 | [ ] |
| 8 | click --coords | 坐标点击 | [ ] |
| 9 | click --query | 文本查找点击 | [ ] |
| 10 | type --text | 输入文本 | [ ] |
| 11 | type --clear | 清空并输入 | [ ] |
| 12 | hotkey | 快捷键 | [ ] |
| 13 | clipboard get | 读取剪贴板 | [ ] |
| 14 | clipboard set | 写入剪贴板 | [ ] |
| 15 | clipboard clear | 清空剪贴板 | [ ] |
| 16 | scroll | 滚动 | [ ] |
| 17 | window move | 移动窗口 | [ ] |
| 18 | window resize | 缩放窗口 | [ ] |
| 19 | window list | 列出窗口 | [ ] |
| 20 | menu list | 列出菜单 | [ ] |
| 21 | menu click | 点击菜单 | [ ] |
| 22 | app focus | 聚焦应用 | [ ] |
| 23 | app quit | 退出应用 | [ ] |
| 24 | window minimize/close | 最小化/关闭 | [ ] |
| E1 | 错误：应用不存在 | 友好错误信息 | [ ] |
| E2 | 错误：无效坐标 | 友好错误信息 | [ ] |
| E3 | 错误：缺少参数 | 友好错误信息 | [ ] |
| E4 | 错误：未知按键 | 友好错误信息 | [ ] |
