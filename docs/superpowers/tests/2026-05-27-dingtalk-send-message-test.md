# 实战测试：钉钉发送消息

> 任务：给钉钉联系人 "MOJI小秘书" 发送 "你是谁，在干嘛？"
> 日期：2026-05-27

---

## 执行步骤回顾

### 步骤 1：聚焦钉钉 ✅

```bash
swift run macos app --action focus --name 钉钉
# → {"action":"focus","app":"钉钉","pid":2874}
```

### 步骤 2：查看元素 ✅

```bash
swift run macos see --app 钉钉 --human
# → 应用: 钉钉 | 元素数: 33
# 发现 T1 [AXTextField] 在底部
```

### 步骤 3：尝试打开搜索（第一次尝试 ❌）

```bash
swift run macos hotkey --keys cmd,f
swift run macos type --text "MOJI小秘书"
```

**问题：** Cmd+F 没有正确打开搜索，或搜索打开后焦点丢失，文本被输入到消息框而非搜索栏。

### 步骤 4：处理遮挡的文档窗口 ✅

```bash
swift run macos window --action list --app 钉钉
# 发现两个窗口：
# index 0: "钉钉"（主窗口）
# index 1: "...ASR结果接入文档 · 钉钉文档"

swift run macos window --action close --app 钉钉 --title "钉钉文档"
# 关闭文档窗口
```

**经验：** 钉钉有多窗口，文档窗口会遮挡主窗口，需要先关闭/最小化。

### 步骤 5：通过菜单打开搜索 ✅

```bash
swift run macos menu --action click --app 钉钉 --path "修改 > 搜索"
# → 成功打开搜索面板
```

**经验：** 
- 钉钉的菜单是 "修改"（不是"编辑"）
- 搜索快捷键标注为 ⌘F 但通过菜单触发更可靠

### 步骤 6：搜索 "MOJI" ✅

```bash
swift run macos type --text "MOJI"
```

**结果：** 搜索成功，在结果中看到了 "MOJI小秘书" 和 "MOJI工单"。

### 步骤 7：选择搜索结果（第一次尝试 ❌）

**尝试 A：坐标点击**
```bash
swift run macos click --coords 200,252
```
❌ 没有成功选中结果（坐标计算不够精确）

**尝试 B：键盘导航**
```bash
swift run macos hotkey --keys arrow_down  # 按3次
```
❌ 焦点没有在搜索结果上，而是跳到了聊天列表

### 步骤 8：第二次搜索 — 导航到对话 ✅ (部分成功)

第二次打开搜索并输入 "MOJI" 后，钉钉自动导航到了 MOJI小秘书 的对话页面。

**验证截图显示：** MOJI小秘书 的聊天历史（天气提醒、打卡等消息）正确显示。

### 步骤 9：发送消息 ❌

```bash
swift run macos click --coords 650,480   # 点击消息输入框
swift run macos type --text "你是谁，在干嘛？" --clear --press-return
```

**问题：** 消息发送到了错误的聊天窗口（"[会议群]Amar 语音房数据接入"），不是 MOJI小秘书。

---

## 问题分析

### 问题 1：焦点管理不可靠

| 现象 | 原因 |
|------|------|
| 搜索栏点击无响应 | 钉钉使用 Electron/Web 渲染，搜索栏不是标准 AX 控件 |
| 文字输入到错误位置 | 焦点在搜索面板和消息框之间跳转 |
| 键盘导航失效 | 搜索结果列表不响应标准 AX 焦点导航 |

### 问题 2：多窗口干扰

| 现象 | 原因 |
|------|------|
| 截图始终显示文档窗口 | ScreenCaptureKit 选中第一个匹配 PID 的窗口 |
| 点击坐标命中错误窗口 | 文档窗口覆盖在主窗口上方 |

### 问题 3：搜索结果选择困难

| 现象 | 原因 |
|------|------|
| 坐标点击不精确 | 搜索面板是浮动覆盖层，坐标偏移不确定 |
| 键盘导航无法选择结果 | 钉钉自定义 UI 不遵循标准 AX 焦点链 |

---

## 改进建议

### 短期（立即可做）

1. **截图辅助定位**：先截图确认当前状态，再计算坐标
2. **菜单触发优于快捷键**：使用 `menu --action click` 比 `hotkey` 更可靠
3. **多窗口处理**：操作前先 `window --action list` 检查并关闭干扰窗口
4. **发送前验证**：点击输入框后截图确认焦点在正确位置

### 中期（代码改进）

1. **添加 `--window-title` 参数到 `see --screenshot`**：指定截取哪个窗口
2. **添加 `grave`（反引号）到 keyCodeMap**：支持 ⌘\` 切换窗口
3. **添加 `see` 自动 focus 选项**：确保元素列表完整
4. **截图标注坐标网格**：辅助手动计算坐标

### 长期（架构改进）

1. **元素文本匹配点击**：通过文本内容定位元素（如 `click --text "MOJI小秘书"`）
2. **等待元素出现**：添加 `wait-for` 命令等待特定元素/文本出现后再操作

---

## 正确的操作流程（建议）

```bash
# 1. 聚焦钉钉
swift run macos app --action focus --name 钉钉

# 2. 清理干扰窗口
swift run macos window --action list --app 钉钉
# 如有多余窗口则关闭
swift run macos window --action close --app 钉钉 --title "钉钉文档"

# 3. 通过菜单打开搜索（最可靠）
swift run macos menu --action click --app 钉钉 --path "修改 > 搜索"
sleep 1

# 4. 输入搜索关键词
swift run macos type --text "MOJI小秘书"
sleep 2

# 5. 截图确认搜索结果
swift run macos see --app 钉钉 --screenshot /tmp/search-result.png

# 6. 按 Enter 确认第一个结果（或计算坐标点击）
swift run macos hotkey --keys return
sleep 1

# 7. 截图确认进入了正确的对话
swift run macos see --app 钉钉 --screenshot /tmp/chat-confirm.png

# 8. 点击消息输入框（根据 see 返回的元素坐标）
swift run macos click --coords <T1的中心坐标>

# 9. 输入并发送
swift run macos type --text "你是谁，在干嘛？" --press-return
```
