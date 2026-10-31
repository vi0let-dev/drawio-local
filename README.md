# drawio-local —— DSH skill

> **Offline, paper-ready diagrams.** Turn Mermaid or draw.io XML into PNG / SVG / PDF with the locally
> installed draw.io Desktop CLI — no MCP server, no cloud rasterizer, nothing leaves the machine.
> An interactive skill flow clarifies the request, offers research-oriented palette and layout
> presets, shows a preview, then exports the formats you pick.

用**本机安装的 draw.io Desktop 命令行**把 Mermaid / `.drawio` / `.csv` / `.vsdx` 离线导出成 PNG、SVG、PDF。
不联网、不上传、不依赖 `mcp.draw.io`，也不需要 `@drawio/mcp`。

面向**科研绘图**：内置一套交互流程，会先用弹窗问清图的内容、配色风格与导出格式，再动手画。

## 目录结构

```
drawio-local/
├── SKILL.md                      # 技能正文：交互流程、配色套用、导出命令、故障处理
├── README.md                     # 本文件
├── references/
│   ├── cli-reference.md          # draw.io Desktop 完整命令行参数表
│   └── style-presets.md          # 论文配色/风格预设（黑白灰、Okabe–Ito、期刊蓝灰、高对比）
├── scripts/
│   └── Export-Drawio.ps1         # 包装脚本：找 exe、等待进程、多格式批量、校验输出
└── examples/
    ├── basic.mmd / basic.drawio  # 最简示例
    ├── paper-flow.mmd            # 期刊蓝灰配色的论文风示例
    ├── paper-preview.png / paper.svg
    └── preview.png
```

## 交互流程（SKILL.md 里已写成硬性步骤）

```
① 需求够不够清楚？ ── 否 ─▶ 弹窗 A：图类型 / 必含要素
        ▼
② 弹窗 B：配色（黑白灰｜Okabe–Ito｜期刊蓝灰｜高对比）+ 风格 + 版面宽度
        ▼
③ 生成图源（Mermaid 或 draw.io XML，套用所选预设）
        ▼
④ 先导一张 PNG 预览给用户看
        ▼
⑤ 弹窗 C（多选）：SVG / PNG / PDF / JPG / 保留 .drawio 源文件
        ▼
⑥ 批量导出 + present 交付
```

弹窗一律走 `ask_user_question`；工具不可用时退化为一条项目符号提问。

## 前置条件

- Windows，已安装 draw.io Desktop 32.x（任意安装位置：脚本会自动在 `Program Files`、`%LOCALAPPDATA%\Programs` 和各盘符的 `draw.io` 目录下查找；也可用 `-DrawioExe` 或 `DRAWIO_EXE` 直接指定）。
- Windows PowerShell 5.1 或 PowerShell 7+。
- 不需要 Node、不需要 Python、不需要联网。

## 安装（自行决定安装位置）

DSH 会从以下位置发现技能（目录名 = 技能名，且必须包含 `SKILL.md`）：

| 作用域 | 路径 |
| --- | --- |
| 用户级（推荐） | `%USERPROFILE%\.dsh\skills\drawio-local\` |
| 项目级 | `<项目根>\.dsh\skills\drawio-local\` |
| 兼容 Claude 布局 | `%USERPROFILE%\.agents\skills\drawio-local\` |

安装 = 把整个 `drawio-local` 文件夹复制过去，然后重启 DSH 或在新的会话里确认技能出现。卸载 = 删除该文件夹。

```powershell
Copy-Item -Recurse -Force .\drawio-local "$env:USERPROFILE\.dsh\skills\drawio-local"
```

## 验证

```powershell
# 1) 能解析到 draw.io Desktop
powershell -NoProfile -File "$env:USERPROFILE\.dsh\skills\drawio-local\scripts\Export-Drawio.ps1" -Check

# 2) 真跑一次多格式导出
powershell -NoProfile -File "$env:USERPROFILE\.dsh\skills\drawio-local\scripts\Export-Drawio.ps1" `
  -InputPath "$env:USERPROFILE\.dsh\skills\drawio-local\examples\paper-flow.mmd" `
  -OutputPath "$env:TEMP\paper" -Format png,svg -Embed -Border 12 -Scale 2
```

应打印两个 `wrote ...`，并在 `%TEMP%` 下得到 `paper.png` 与 `paper.svg`。

## 脚本用法

```powershell
Export-Drawio.ps1 -InputPath <文件或目录> [-OutputPath <文件或目录>]
                  [-Format png,svg,pdf,jpg,xml,html] [-Embed] [-Transparent]
                  [-Border N] [-Quality N] [-Scale N] [-Recursive]
                  [-DrawioExe <路径>] [-TimeoutSeconds N] [-Check] [-WhatIf]
```

| 参数 | 说明 |
| --- | --- |
| `-Format` | 一个或多个格式，逗号分隔；多值时逐个导出（`-Format png,svg`） |
| `-Scale` | 放大倍数，论文位图常用 `2` 或 `3` 达到 ~300 dpi |
| `-Embed` | 在 png/svg/pdf 里嵌入图源，导出后仍可编辑 |
| `-Transparent` | png/svg 透明背景 |
| `-Border` | 四周留白像素 |
| `-Recursive` | 目录输入时递归 |
| `-Check` | 只报告找到的 exe 与版本 |
| `-WhatIf` | 只打印将执行的命令行 |

退出码：`0` 成功、`1` 参数/解析错误、`2` draw.io 失败、`3` 输出缺失、`4` 超时。exe 查找顺序：`-DrawioExe` → `DRAWIO_EXE` → `PATH` → 常见安装目录 → 卸载注册表项。

## 实测记录

Windows 10 + draw.io Desktop 32.6.1，脚本在**沙箱外**执行：

| 输入 | 输出 | 耗时 | 大小 |
| --- | --- | --- | --- |
| `examples/basic.mmd` | PNG（`-e -b 10`） | 2.6 s | 53,406 B |
| `examples/basic.drawio` | SVG（`-e`） | 1.3 s | 36,907 B |
| `examples/basic.mmd` | PDF | 1.6 s | 48,546 B |
| `examples/paper-flow.mmd` | PNG + SVG（`-Format png,svg -Scale 2`） | 2.4 s + 1.3 s | 87,606 B + 131,899 B |

`examples/preview.png` 与 `examples/paper-preview.png` 就是渲染结果。

## 已知限制

- **不能在 DSH 沙箱 shell 里跑**：draw.io 是 Electron 应用，启动时要创建 Chromium 的命名管道（mojo IPC），沙箱禁止，进程以 `0x80000003` 退出且不产生输出文件，stderr 为 `platform_channel.cc ... Access is denied. (0x5)`。在普通终端里跑，或让该调用以非沙箱权限执行。
- 导出是**无头**的：只负责转换文件，不打开编辑器窗口；要改图就打开 `.drawio` 源文件。
- Mermaid 由 draw.io 自带解析器转换，个别最新语法可能不支持；复杂图优先用 draw.io XML。
- **SVG 里的富文本**：带 `html=1` 的标签在 SVG 中会导出为 `foreignObject` 并附一份位图兜底，Illustrator 之类不支持 `foreignObject` 的软件里文字不可编辑。需要"文字可编辑的矢量图"时，用 PDF，或把标签改成纯文本（`html=0`）后再导出。
- 多格式导出在第一个失败处停止，已产出的文件会列出。

## 许可与来源

脚本与文档为本仓库原创，MIT。命令行参数事实来自 draw.io Desktop 32.6.1 安装包内的 `src/main/args.js`。
