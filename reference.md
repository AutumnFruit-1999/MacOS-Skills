# macos CLI 完整命令参考

## 全局选项

所有命令支持 `--human` 标志，切换为人类可读输出（默认 JSON）。

---

## macos see

发现目标应用中的可交互 UI 元素。

```
macos see [--app <name>] [--screenshot <path>] [--annotate] [--max-depth <n>] [--human]
```

| 参数 | 说明 |
|------|------|
| `--app` | 目标应用名（省略则使用前台应用） |
| `--screenshot` | 截图保存路径（省略则不截图） |
| `--annotate` | 在截图上标注元素 ID（需配合 --screenshot） |
| `--max-depth` | AX 树最大遍历深度（默认 10） |

---

## macos inspect

查看原始 Accessibility 树结构（层级格式）。

```
macos inspect [--app <name>] [--max-depth <n>] [--human]
```

| 参数 | 说明 |
|------|------|
| `--app` | 目标应用名 |
| `--max-depth` | 最大深度（默认 5） |

---

## macos click

点击屏幕元素或坐标。

```
macos click [--query <text>] [--coords <x,y>] [--app <name>] [--double] [--right]
```

| 参数 | 说明 |
|------|------|
| `--query` | 按文本内容实时查找元素并点击其中心 |
| `--coords` | 直接点击坐标，格式 `x,y` |
| `--app` | 限定 query 搜索范围 |
| `--double` | 双击 |
| `--right` | 右键点击 |

---

## macos type

输入文本。

```
macos type [--text <string>] [--coords <x,y>] [--clear] [--press-return] [--delay <ms>]
```

| 参数 | 说明 |
|------|------|
| `--text` | 要输入的文本 |
| `--coords` | 先点击此坐标聚焦（格式 `x,y`） |
| `--clear` | 输入前清空字段（Cmd+A, Delete） |
| `--press-return` | 输入后按回车 |
| `--delay` | 按键间延迟，毫秒（默认 5） |

---

## macos hotkey

按下键盘快捷键。

```
macos hotkey --keys <key_combo>
```

| 参数 | 说明 |
|------|------|
| `--keys` | 逗号分隔的按键组合 |

支持的修饰键：`cmd`, `shift`, `alt`/`option`, `ctrl`, `fn`
支持的按键：`a-z`, `0-9`, `space`, `return`, `tab`, `escape`, `delete`, `arrow_up/down/left/right`, `f1-f12`

示例：`cmd,c` / `cmd,shift,t` / `cmd,alt,escape`

---

## macos scroll

滚动。

```
macos scroll --direction <up|down|left|right> [--amount <n>] [--coords <x,y>]
```

| 参数 | 说明 |
|------|------|
| `--direction` | 方向：up, down, left, right |
| `--amount` | 滚动行数（默认 3） |
| `--coords` | 先移动鼠标到此坐标再滚动 |

---

## macos app

管理应用。

```
macos app --action <launch|quit|focus|list> [--name <app>] [--force] [--wait] [--human]
```

| 参数 | 说明 |
|------|------|
| `--action` | launch/quit/focus/list |
| `--name` | 应用名（launch/quit/focus 需要） |
| `--force` | 强制退出 |
| `--wait` | 等待应用就绪（launch 用） |

---

## macos window

管理窗口。

```
macos window --action <move|resize|close|minimize|maximize|focus|list>
             [--app <name>] [--title <text>] [--x <n>] [--y <n>] [--width <n>] [--height <n>]
```

| 参数 | 说明 |
|------|------|
| `--action` | move/resize/close/minimize/maximize/focus/list |
| `--app` | 目标应用名 |
| `--title` | 窗口标题（部分匹配） |
| `--x`, `--y` | 位置（move 用） |
| `--width`, `--height` | 尺寸（resize 用） |

---

## macos menu

操作应用菜单栏。

```
macos menu --action <list|click> --app <name> [--path <"Menu > Item">]
```

| 参数 | 说明 |
|------|------|
| `--action` | list（列出菜单）/ click（点击菜单项） |
| `--app` | 目标应用名 |
| `--path` | 菜单路径，如 `"File > Save"` |

---

## macos clipboard

读写系统剪贴板。

```
macos clipboard --action <get|set|clear> [--text <string>]
```

| 参数 | 说明 |
|------|------|
| `--action` | get/set/clear |
| `--text` | 要设置的文本（set 用） |
