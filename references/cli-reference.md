# draw.io Desktop 命令行参考（Windows）

以下参数表来自本机安装的 **draw.io Desktop 32.6.1**（`resources/app.asar` 内 `src/main/args.js`），不是网上抄的通用文档。不同大版本的参数可能增减，以 `draw.io.exe --help`（部分版本支持）和实际安装包为准。

## 参数

| 短 | 长 | 含义 |
| --- | --- | --- |
| `-x` | `--export` | 导出。输入除 `.drawio` 外还支持 `.vsdx`、`.csv`、Mermaid（`.mmd`/`.mermaid`） |
| `-f` | `--format` | 输出格式：`pdf, png, jpg, svg, xml, html`；**默认 `pdf`**。若 `-o` 已带扩展名，此项被忽略 |
| `-o` | `--output` | 输出文件或目录；省略时用输入文件名加格式后缀 |
| `-e` | `--embed-diagram` | 在导出文件里嵌一份图源（仅 png/svg/pdf），导出后仍可在 draw.io 中编辑 |
| `-t` | `--transparent` | PNG/SVG 透明背景 |
| `-b` | `--border` | 图周围留白像素，默认 0 |
| `-q` | `--quality` | JPEG 质量，默认 90 |
| `-s` | `--scale` | 缩放图尺寸（如 `2` = 2 倍分辨率） |
| `-p` | `--page-index` | 选某一页（从 1 开始）；图片格式不指定时取第一页 |
| `-a` | `--all-pages` | 导出所有页（PDF、HTML） |
| `-g` | `--page-range` | 页范围（从 1 开始，仅 PDF） |
| `-l` | `--layers` | 选择要导出的图层（作用于所有页），默认全部 |
| `-u` | `--uncompressed` | 输出未压缩 XML（XML/SVG） |
| `-r` | `--recursive` | 目录输入时递归子目录 |
| `-k` | `--check` | 不覆盖已存在的输出文件 |
| `-c` | `--create` | 没有传入文件时新建空文件 |
| `-z` | `--zoom` | 应用界面缩放（与导出无关） |

另有 SVG 专用开关：`--embed-svg-images`、`--embed-svg-fonts <true/false>`、`--embed-svg-metadata`。

## 命令行形态

```
draw.io.exe -x -f png -e -b 10 -o out.png in.mmd
draw.io.exe -x -f pdf -a -o out.pdf in.drawio        # 所有页
draw.io.exe -x -f svg -p 2 -o page2.svg in.drawio    # 第 2 页
draw.io.exe -x -f png -r -o outdir indir             # 整个目录
```

## 输入/输出矩阵

| 输入 | 可导出 |
| --- | --- |
| `.drawio` / `.xml`（mxGraphModel / mxfile） | 全部格式 |
| Mermaid `.mmd` / `.mermaid` | 全部格式（由 draw.io 自带的 Mermaid 解析器转换） |
| `.csv` | 全部格式（按表格生成图） |
| `.vsdx`（Visio） | 全部格式 |

注意：`-e` 嵌入的图源只有 png/svg/pdf 有，其他格式会被忽略。

## 行为细节

- **GUI 子系统程序**：用 PowerShell 的 `&` 调用会立即返回，不等导出完成；必须 `Start-Process -Wait`（本 skill 的脚本已处理）或用 `cmd /c start /wait`。
- **退出码**：成功为 0。启动阶段被环境杀掉时可能是 `-2147483645`（`0x80000003`，STATUS_BREAKPOINT），此时不会有输出文件。
- **不创建父目录**：`-o` 的父目录必须已存在。
- **同格式批量**：目录输入时输出目录用 `-o` 指定，否则写在输入目录旁。
- **渲染**：导出在本地进程内完成，不调用 `convert.diagrams.net` 之类的云服务；图内容不会因为导出而离开本机。

## 常见 stderr 与含义

| 现象 | 含义 / 处理 |
| --- | --- |
| `Check failed: . : Access is denied. (0x5)`，来自 `platform_channel.cc` | Chromium 的 mojo 命名管道创建被拒 → 运行在受限沙箱里，需在普通终端或更高权限下运行 |
| `Failed to grant sandbox access to cache directory` | 同类问题的伴随错误，可忽略前一条才是根因 |
| 退出码 0 但无文件 | 检查 `-o` 父目录、输入文件路径、是否被 `-k` 跳过 |
