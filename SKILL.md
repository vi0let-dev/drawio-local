---
name: drawio-local
description: 用本机 draw.io Desktop 命令行把 Mermaid / .drawio / .csv / .vsdx 离线导出成 PNG、SVG、PDF；内置科研绘图配色与风格预设，会先用弹窗询问需求细节、配色风格与导出格式，全程不联网、不走 MCP。
whenToUse: 用户要画架构图/流程图/时序图/ER 图并需要图片文件（尤其论文、学位论文、技术报告用图），或要把已有 .drawio、Mermaid 文本转成 png/svg/pdf，且要求本地离线、数据不外发时。
---

# 本地离线生成 draw.io 图（科研绘图向）

本 skill 调用**本机已安装的 draw.io Desktop**（Electron 版的 `draw.io.exe`）渲染图源文件。它不走网络、不需要 `@drawio/mcp`、不需要 `mcp.draw.io`，图数据只落在本机磁盘上。

> **执行环境前提**：draw.io Desktop 是 Electron 程序，启动时要创建 Chromium 的命名管道（mojo IPC）。**在 DSH 的沙箱 shell 里它会以 `0x80000003` 退出，不产生任何文件**。要么让用户在自己的终端里执行，要么让这次调用以非沙箱权限运行。看到该报错不要重试同一命令，按“故障处理”走。

## 交互流程（必须按顺序走）

```
① 需求是否够清楚？ ── 否 ─▶ 弹窗 A：澄清（图类型/要素/方向）
        │ 是
        ▼
② 弹窗 B：配色 + 风格 + 版面（论文向预设）
        ▼
③ 生成图源（Mermaid 或 draw.io XML，套用所选预设）
        ▼
④ 先导一张 PNG 预览，给用户看
        ▼
⑤ 弹窗 C：导出哪些格式（多选）
        ▼
⑥ 按选择批量导出 → present 交付
```

弹窗一律用 `ask_user_question` 工具；该工具不可用时，用一条简短的项目符号消息问同样的问题，不要退化成“随便画一版”。

### ① 什么时候需要弹窗 A

**信息足够**（直接进 ②）：用户给了明确的图类型 + 至少两个具体实体/参与者 + 关系或流向。

**信息不足**（必须先问）：满足任一条就要问，最多 3 个问题，一次问完：

- 没说是什么图（流程图 / 架构图 / 时序图 / ER / 状态机 / 泳道）；
- 只有一句模糊描述（“画一下我们的系统”），没有节点或模块；
- 关系或方向不明（谁调用谁、数据往哪流、时间顺序）；
- 有互相冲突或可多种解读的说法。

弹窗 A 示例（按实际缺什么裁剪，别照抄所有问题）：

```json
{
  "questions": [
    {
      "id": "diagram-type",
      "header": "图表类型",
      "question": "这张图你想画成哪种？",
      "options": [
        { "label": "流程图 / 数据流（推荐）", "description": "按步骤或数据流向展开" },
        { "label": "系统架构图", "description": "模块、层次、依赖关系" },
        { "label": "时序图", "description": "参与者之间的调用顺序" },
        { "label": "ER / 类图", "description": "实体、字段、关系" },
        { "label": "状态机 / 状态转移", "description": "状态与触发条件" },
        { "label": "其他（我补充说明）" }
      ]
    },
    {
      "id": "scope",
      "header": "要包含什么",
      "question": "图里必须出现哪些部分？（可多选）",
      "multi_select": true,
      "options": [
        { "label": "数据/输入来源" },
        { "label": "核心处理模块" },
        { "label": "存储/数据库" },
        { "label": "外部服务或第三方 API" },
        { "label": "用户/角色" },
        { "label": "部署环境（云/边缘/本地）" }
      ]
    }
  ]
}
```

问完之后若仍有歧义，**只再确认一轮**（“我按 A→B→C 这样画，对吗？”），然后带着明确假设继续，并在交付时说明假设。

### ② 弹窗 B：配色与风格（科研/论文向）

除非用户已经指定了配色或给了模板，**每次都要问**。一次弹两个问题（配色、风格），版面尺寸可以合并成第三个问题。

```json
{
  "questions": [
    {
      "id": "palette",
      "header": "配色",
      "question": "这张图主要用在哪里？我按对应配色生成。",
      "options": [
        { "label": "黑白灰（印刷最安全，推荐）", "description": "不依赖颜色区分，任何期刊/黑白打印都稳" },
        { "label": "色盲友好 Okabe–Ito", "description": "彩色但色盲可辨，Nature/Science 系常用" },
        { "label": "期刊蓝灰（Nature/Science 观感）", "description": "浅灰蓝底 + 深蓝描边，适合系统总览图" },
        { "label": "高对比（答辩/汇报投屏）", "description": "饱和填充，不适合印刷正文图" },
        { "label": "沿用我给的模板/已有配色", "description": "我会按照你提供的样式来" }
      ]
    },
    {
      "id": "style",
      "header": "风格",
      "question": "线条和形状偏好？",
      "options": [
        { "label": "极简细线（推荐）", "description": "直/圆角矩形、1px 描边、无阴影" },
        { "label": "直角功能块", "description": "纯矩形、正交连线，最克制" },
        { "label": "带分组容器/泳道", "description": "分模块或分角色，适合复杂系统" }
      ]
    },
    {
      "id": "width",
      "header": "版面",
      "question": "最终图的宽度按哪种来？",
      "options": [
        { "label": "单栏 85 mm（推荐）", "description": "多数期刊单栏宽" },
        { "label": "双栏 170 mm", "description": "通栏大图" },
        { "label": "幻灯片 16:9" },
        { "label": "暂不限制" }
      ]
    }
  ]
}
```

用户回答后，按下表套用 [references/style-presets.md](references/style-presets.md) 的对应章节：

| 用户选择 | 预设章节 | 关键做法 |
| --- | --- | --- |
| 黑白灰 | §1 | 填充只用 `#FFFFFF/#F2F2F2/#D9D9D9`，描边黑，靠形状/线型表达语义 |
| Okabe–Ito | §2 | 8 色主色 + 20% 淡色填充，`classDef` 直接抄 |
| 期刊蓝灰 | §3 | `#F5F7FA/#D6E4F0/#8FB8DE` + `#1F3A5F` 描边 |
| 高对比 | §4 | 深色填充 + 白字，仅用于投屏 |
| 极简细线 | §7 | `shadow=0;html=0;strokeWidth=1;fontFamily=Helvetica;fontSize=11` |
| 单栏 85 mm | §5 | Mermaid 尽量短句；draw.io 用 pageWidth≈321（85mm@96dpi）再 `-Scale 2` 出图 |

### ③ 生成图源

- 优先 **Mermaid**（`flowchart`/`sequenceDiagram`/`erDiagram`），只有需要精确控制位置、容器、图标时才写 draw.io XML。
- Mermaid 必须加 `%%{init:%%}` 关掉默认彩色主题，否则预设会打架：

```
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'11px','lineColor':'#333333','primaryColor':'#FFFFFF','primaryBorderColor':'#333333','primaryTextColor':'#1A1A1A'},'flowchart':{'curve':'linear','nodeSpacing':40,'rankSpacing':55}}}%%
```

- 配色用 `classDef` 落在节点上，例如 `class A,B main;`。
- 文件写到任务工作区（`diagram.mmd` / `diagram.drawio`），**不要写进 skill 目录**，UTF-8 无 BOM。

### ④ 先给预览

生成后先导出一张 PNG 预览（`-Scale 2`，让用户看清），用 `read_image` 自检排版（文字溢出、连线穿过节点、比例失衡），再把图片给用户看。

### ⑤ 弹窗 C：导出格式（多选）

等用户确认图没问题后再问格式：

```json
{
  "questions": [
    {
      "id": "formats",
      "header": "导出格式",
      "question": "要导出哪些文件？（可多选，SVG + PNG 是最常用的组合）",
      "multi_select": true,
      "options": [
        { "label": "SVG（矢量，投稿首选，推荐）", "description": "任意缩放不失真，Word/LaTeX/Illustrator 都能用" },
        { "label": "PNG（位图，预览/PPT 用，推荐）", "description": "我按 300 dpi 左右导出" },
        { "label": "PDF（矢量，LaTeX \\includegraphics 直接用）" },
        { "label": "JPG（体积小，慎用于线条图）" },
        { "label": "保留 .drawio 源文件（之后可继续编辑）" }
      ]
    }
  ]
}
```

用户可能选多个；未选择任何项时按默认 **SVG + PNG** 处理并说明。`.drawio` 源文件不需要“导出”，生成阶段就已经在工作区里，直接一起交付即可。

### ⑥ 批量导出与交付

脚本支持一次多格式（见下节），把用户选中的格式拼给 `-Format` 即可。最后 `present` 所有实际产出文件（最多 4 个），并在回答里说明：用了哪个配色、尺寸假设、以及源文件位置。

## 导出命令

`$SKILL` = skill 安装目录，用户级为 `%USERPROFILE%\.dsh\skills\drawio-local`；装在别处就替换。

```powershell
# 前置检查（每次任务先跑一次）
powershell -NoProfile -File "$env:USERPROFILE\.dsh\skills\drawio-local\scripts\Export-Drawio.ps1" -Check

# 预览
powershell -NoProfile -File "$env:USERPROFILE\.dsh\skills\drawio-local\scripts\Export-Drawio.ps1" `
  -InputPath .\diagram.mmd -OutputPath .\diagram-preview.png -Format png -Scale 2 -Border 10

# 按用户选择多格式导出
powershell -NoProfile -File "$env:USERPROFILE\.dsh\skills\drawio-local\scripts\Export-Drawio.ps1" `
  -InputPath .\diagram.mmd -OutputPath .\diagram -Format svg,png -Embed -Border 10 -Scale 2
```

`-OutputPath .\diagram` 不带扩展名时，会产出 `diagram.svg`、`diagram.png`。带扩展名也一样（扩展名被去掉后按格式重拼）。

## 支持矩阵

| 维度 | 取值 |
| --- | --- |
| 输入 | `.drawio`、`.xml`、`.vsdx`、`.csv`、Mermaid（`.mmd`/`.mermaid`） |
| 输出 | `png`、`svg`、`pdf`、`jpg`、`xml`、`html`（默认 `pdf`；可多格式一次导出） |
| 常用参数 | `-Format`、`-OutputPath`、`-Embed`、`-Transparent`、`-Border`、`-Quality`、`-Scale`、`-Recursive` |

完整参数见 [references/cli-reference.md](references/cli-reference.md)；配色与版面预设见 [references/style-presets.md](references/style-presets.md)。

## 交付前自检

1. 转灰度后各块仍能区分（明度差 ≥ 20%）；
2. 最小字号 ≥ 7 pt（按目标宽度换算）；
3. 线宽 ≥ 0.25 pt，无阴影/渐变/发光；
4. 颜色之外有第二编码（形状/线型/标签）；
5. 文字没有溢出图框、没有被连线穿过；
6. 没有外部字体/位图徽标依赖（用 Helvetica/Arial）。

## 故障处理

**退出码 `-2147483645`（0x80000003）且没有任何输出文件**：进程在启动阶段就被杀掉了。最常见原因是它在 **DSH 的沙箱 shell 里运行**——Chromium 需要创建命名管道（mojo IPC），沙箱禁止，stderr 会出现：

```
FATAL:mojo/public/cpp/platform/platform_channel.cc:108] Check failed: . : 拒绝访问。 (0x5)
```

这不是命令写错，重试无用。处理顺序：

1. 向用户说明“沙箱内无法启动 draw.io Desktop”，请求以非沙箱权限重跑这一次导出（DSH 会弹授权）；
2. 或者把命令给用户，让他在自己的 PowerShell 里执行：
   `& "<exe>" -x -f png -e -b 10 -o "<out>" "<in>"`；
3. 不要改用 `npx @drawio/mcp` 或 `mcp.draw.io` 绕过——那会把图送到网络或改变交付形态，超出本 skill 的约定。

**退出码 0 但没有输出**：脚本会自动创建输出父目录；直接调 exe 时它不会建，需要自己先建好。

**导出的图是空白/报错**：多为 Mermaid 语法不被支持（draw.io 自带 Mermaid 解析器，并非完整支持所有 mermaid 版本特性）。先用最小图（两三个节点）验证，再逐步加内容。

**中文乱码**：图源文件保存为 UTF-8（无 BOM）。draw.io 对 UTF-8 支持良好。

**多格式导出中途失败**：脚本会在第一个失败处停止并列出已产出的文件；把失败原因告知用户，不要谎称全部成功。

## 已验证

在 Windows + draw.io Desktop 32.6.1 上实测（沙箱外）：

| 输入 | 输出 | 耗时 | 结果 |
| --- | --- | --- | --- |
| `examples/basic.mmd`（Mermaid） | `png`，`-e -b 10` | 2.6 s | 53,406 字节，`examples/preview.png` |
| `examples/basic.drawio`（XML） | `svg`，`-e` | 1.3 s | 36,907 字节 |
| `examples/basic.mmd`（Mermaid） | `pdf` | 1.6 s | 48,546 字节 |
| `examples/paper-flow.mmd`（期刊蓝灰配色） | `png` + `svg`（`-Format png,svg -Scale 2`） | 2.4 s + 1.3 s | 87,606 B + 131,899 B，`examples/paper-preview.png` |

## 交付

- 图源文件（`.mmd` / `.drawio`）和导出结果都留在任务工作区，方便用户二次编辑。
- 不要把中间产物写进本 skill 目录；本目录在安装位置通常只读。
