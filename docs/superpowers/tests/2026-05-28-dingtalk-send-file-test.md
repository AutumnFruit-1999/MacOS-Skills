# 钉钉文件发送自动化 — 测试文档

本文档记录通过 `macos` CLI 工具向钉钉联系人发送文件的完整测试流程及结果。

## 前置条件

1. macOS 14+ (Sonoma)
2. 钉钉桌面客户端已安装并登录
3. 辅助功能权限已授予（系统设置 > 隐私与安全性 > 辅助功能）
4. 屏幕录制权限已授予（OCR 功能需要）
5. 目标联系人已在钉钉好友/联系人列表中
6. 待发送文件已存在于桌面

## 测试环境

- **测试日期：** 2026-05-28
- **待发送文件：** `/Users/user/Desktop/GitHub_Trending_2026-05-26.xlsx`（8.2 KB）
- **目标联系人：** 邱沛鑫
- **使用工具：** `macos` CLI + `osascript`

---

## 测试用例

### test_send_file_01: 聚焦钉钉应用

**测试目标：** 验证钉钉可被正常聚焦

```bash
macos app --action focus --name "钉钉"
```

**预期结果：** 返回 `{"action":"focus","app":"钉钉","pid":<pid>}`，钉钉窗口在前台可见。

**实际结果：** PASS

```json
{"action":"focus","app":"钉钉","pid":3347}
```

---

### test_send_file_02: 确认钉钉窗口可见

**测试目标：** 验证钉钉窗口存在且可操作

```bash
macos window --action list --app "钉钉"
```

**预期结果：** 返回至少一个窗口对象。

**实际结果：** PASS

```json
[{"app":"钉钉","index":0,"title":"钉钉"}]
```

---

### test_send_file_03: 通过搜索定位联系人

**测试目标：** 验证可通过搜索找到目标联系人

**步骤 1：打开搜索**
```bash
macos hotkey --keys cmd,k
```

**步骤 2：等待搜索框出现，确认搜索框位置**
```bash
sleep 1
macos ocr --app "钉钉" --query "搜索"
```

**预期结果：** OCR 识别到"搜索"相关文本。

**实际结果：** PASS

```json
{"app":"钉钉","count":1,"elements":[{"confidence":0.3,"frame":{"h":16,"w":129,"x":693,"y":49},"text":"C 搜索或提问（F）"}]}
```

**步骤 3：点击搜索框并输入联系人名称**
```bash
macos click --coords 757,57
sleep 0.5
macos type --text "邱沛鑫"
```

**步骤 4：等待搜索结果并 OCR 定位**
```bash
sleep 1.5
macos ocr --app "钉钉" --query "邱沛鑫"
```

**预期结果：** 搜索结果中包含"邱沛鑫"。

**实际结果：** PASS — 找到 2 个匹配（搜索历史 + 联系人）

---

### test_send_file_04: 点击联系人进入对话

**测试目标：** 验证可从搜索结果进入 1 对 1 对话

```bash
macos click --coords 263,190
sleep 1
```

**验证方式：** 截图确认进入正确对话

```bash
macos see --app "钉钉" --screenshot /tmp/dingtalk_chat.png --human
```

**预期结果：** 进入与邱沛鑫的 1 对 1 对话，界面显示聊天记录和输入框。

**实际结果：** PASS — 截图确认进入了与邱沛鑫的对话，标题显示"我（邱沛鑫）"。

---

### test_send_file_05: 通过剪贴板复制文件

**测试目标：** 验证可通过 osascript 将文件引用写入系统剪贴板

```bash
osascript -e 'set the clipboard to (POSIX file "/Users/user/Desktop/GitHub_Trending_2026-05-26.xlsx")'
```

**预期结果：** 命令执行成功（exit code 0），无输出。

**实际结果：** PASS

**备注：** 当前 `macos clipboard --action set` 仅支持文本，文件复制需通过 `osascript` 绕行。OPT-005 计划增加 `--file` 参数后可直接使用 CLI。

---

### test_send_file_06: 在对话中粘贴文件触发发送确认

**测试目标：** 验证在钉钉对话中 Cmd+V 可触发文件发送确认弹窗

```bash
macos app --action focus --name "钉钉"
sleep 0.3
macos click --coords 850,810
sleep 0.3
macos hotkey --keys cmd,v
```

**预期结果：** 钉钉弹出确认对话框，内容包含文件名。

**实际结果：** PASS — 弹窗显示"发送给 我（邱沛鑫）确定要发送 GitHub_Trending_2026-05-26.xlsx 吗？"

**验证：**
```bash
sleep 1
macos see --app "钉钉" --screenshot /tmp/dingtalk_confirm.png
```

---

### test_send_file_07: 确认发送文件

**测试目标：** 验证点击"确定"按钮可完成文件发送

**步骤 1：OCR 定位确定按钮**
```bash
macos ocr --app "钉钉" --query "确定"
```

**实际结果：** 确定按钮位于 (895, 496, 33x18)

**步骤 2：点击确定按钮**
```bash
macos click --coords 911,505
```

**步骤 3：等待发送完成并验证**
```bash
sleep 2
macos ocr --app "钉钉" --query "GitHub_Trending"
```

**预期结果：** 聊天记录中出现文件消息。

**实际结果：** PASS

```json
{"app":"钉钉","count":1,"elements":[{"confidence":0.5,"frame":{"h":18,"w":226,"x":1150,"y":356},"text":"GitHub_Trending_2026-05-26.xlsx"}]}
```

---

### test_send_file_08: 最终截图验证

**测试目标：** 截图确认文件已成功发送到对话中

```bash
macos see --app "钉钉" --screenshot /tmp/dingtalk_sent.png
```

**预期结果：** 截图显示聊天记录中有文件消息卡片，包含文件名、大小、预览。

**实际结果：** PASS — 截图确认显示：
- 文件名：GitHub_Trending_2026-05-26.xlsx
- 大小：8.2 KB
- 文件预览缩略图可见
- 操作按钮："编辑"、"打开"、"添加到"
- 左侧会话列表邱沛鑫条目显示"[文件]"

---

## 测试结果汇总

| 用例 | 描述 | 结果 |
|------|------|------|
| test_send_file_01 | 聚焦钉钉应用 | PASS |
| test_send_file_02 | 确认窗口可见 | PASS |
| test_send_file_03 | 搜索定位联系人 | PASS |
| test_send_file_04 | 进入 1 对 1 对话 | PASS |
| test_send_file_05 | 剪贴板复制文件 | PASS |
| test_send_file_06 | 粘贴触发发送确认 | PASS |
| test_send_file_07 | 确认发送文件 | PASS |
| test_send_file_08 | 截图最终验证 | PASS |

**总计：** 8/8 PASS

---

## 发现的问题与优化建议

| 问题 | 影响 | 对应优化 |
|------|------|----------|
| `macos clipboard` 不支持文件类型 | 需通过 `osascript` 绕行 | OPT-005 |
| `macos ocr --app` 和 `--region` 互斥 | 需手动计算屏幕绝对坐标 | OPT-006 |
| 工具栏图标按钮无法识别 | 无法自动定位"发送文件"按钮 | OPT-007 |

## 推荐工作流

基于本次测试验证，钉钉发送文件的推荐工作流为：

```bash
# 1. 聚焦钉钉
macos app --action focus --name "钉钉"

# 2. 搜索联系人
macos hotkey --keys cmd,k
sleep 1
macos click --coords <搜索框x>,<搜索框y>
macos type --text "联系人名称"
sleep 1.5

# 3. OCR 定位并点击搜索结果
macos ocr --app "钉钉" --query "联系人名称"
macos click --coords <结果x>,<结果y>
sleep 1

# 4. 复制文件到剪贴板并粘贴（优先策略）
osascript -e 'set the clipboard to (POSIX file "/path/to/file")'
macos click --coords <输入框x>,<输入框y>
macos hotkey --keys cmd,v
sleep 1

# 5. OCR 定位并点击确认
macos ocr --app "钉钉" --query "确定"
macos click --coords <确定x>,<确定y>

# 6. 验证发送成功
sleep 2
macos ocr --app "钉钉" --query "文件名关键词"
```
