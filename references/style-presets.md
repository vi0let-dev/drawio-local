# 科研/论文绘图：配色与风格预设

面向投稿、学位论文、技术报告的图。核心原则：**印刷安全、色盲友好、矢量优先、字号线宽够大**。

使用方式：先在 `ask_user_question` 里让用户选配色与风格，再把下面对应的片段套到生成结果上——Mermaid 用 `%%{init}%%` + `classDef`，draw.io XML 用 `style` 字符串。

---

## 1. 黑白灰（印刷安全，最稳）

适用于：任何期刊、黑白印刷、预算有限的排版。

| 角色 | 填充 | 描边 | 文字 |
| --- | --- | --- | --- |
| 主流程 | `#FFFFFF` | `#000000` | `#000000` |
| 辅助/次要 | `#F2F2F2` | `#4D4D4D` | `#000000` |
| 强调 | `#D9D9D9` | `#000000` | `#000000` |
| 起点/终点 | `#BFBFBF` | `#000000` | `#000000` |

Mermaid：

```
classDef plain fill:#FFFFFF,stroke:#000000,stroke-width:1px,color:#000000
classDef soft  fill:#F2F2F2,stroke:#4D4D4D,stroke-width:1px,color:#000000
classDef spot  fill:#D9D9D9,stroke:#000000,stroke-width:1.2px,color:#000000
```

draw.io：

```
rounded=1;whiteSpace=wrap;html=0;fillColor=#FFFFFF;strokeColor=#000000;strokeWidth=1;fontFamily=Helvetica;fontSize=11;fontColor=#000000;shadow=0;
```

要点：**不要用颜色表达语义**，用形状/线型/标签（实线=主流程，虚线=异步，点线=可选）。

---

## 2. 色盲友好（Okabe–Ito，8 色）

适用于：需要彩色但要求色盲可辨（Nature/Science 系列都推荐这一类）。

| 名称 | 主色（描边/强调） | 建议填充（20% 淡色） |
| --- | --- | --- |
| 橙 Orange | `#E69F00` | `#FDF0D5` |
| 天蓝 Sky | `#56B4E9` | `#E3F2FB` |
| 绿 Green | `#009E73` | `#DDF2EC` |
| 黄 Yellow | `#F0E442` | `#FDFBE0` |
| 深蓝 Blue | `#0072B2` | `#DCEAF5` |
| 朱红 Vermillion | `#D55E00` | `#FBE6D6` |
| 品红 Purple | `#CC79A7` | `#F6E6EE` |
| 黑 Black | `#000000` | `#FFFFFF` |

Mermaid `classDef`：

```
classDef orange fill:#FDF0D5,stroke:#E69F00,stroke-width:1.2px,color:#1A1A1A
classDef sky    fill:#E3F2FB,stroke:#0072B2,stroke-width:1.2px,color:#1A1A1A
classDef green  fill:#DDF2EC,stroke:#009E73,stroke-width:1.2px,color:#1A1A1A
classDef red    fill:#FBE6D6,stroke:#D55E00,stroke-width:1.2px,color:#1A1A1A
classDef purple fill:#F6E6EE,stroke:#CC79A7,stroke-width:1.2px,color:#1A1A1A
```

draw.io：

```
rounded=1;whiteSpace=wrap;html=0;fillColor=#DCEAF5;strokeColor=#0072B2;strokeWidth=1.2;fontFamily=Helvetica;fontSize=11;fontColor=#1A1A1A;shadow=0;
```

---

## 3. 期刊蓝灰（Nature / Science 常见观感）

适用于：方法示意图、系统总览图。

| 角色 | 填充 | 描边 |
| --- | --- | --- |
| 背景/分组容器 | `#F5F7FA` | `#D6E4F0` |
| 主模块 | `#D6E4F0` | `#2E6F9E` |
| 强调模块 | `#8FB8DE` | `#1F3A5F` |
| 关键路径 | `#FFFFFF` | `#1F3A5F`（线宽 1.6） |
| 稀疏强调 | `#FBEAEA` | `#B03A2E` |

Mermaid：

```
classDef gBg   fill:#F5F7FA,stroke:#D6E4F0,stroke-width:1px,color:#1A1A1A
classDef gMain fill:#D6E4F0,stroke:#2E6F9E,stroke-width:1.2px,color:#1A1A1A
classDef gSpot fill:#8FB8DE,stroke:#1F3A5F,stroke-width:1.4px,color:#0B1B2B
```

---

## 4. 高对比（答辩/汇报投屏）

适用于：投影、在线汇报，不是印刷。

| 角色 | 填充 | 描边 | 文字 |
| --- | --- | --- | --- |
| 主 | `#2563EB` | `#1E40AF` | `#FFFFFF` |
| 警示 | `#DC2626` | `#991B1B` | `#FFFFFF` |
| 成功 | `#16A34A` | `#166534` | `#FFFFFF` |
| 强调 | `#F59E0B` | `#B45309` | `#1A1A1A` |

注意：这类填充要配 `fontColor:#FFFFFF`，且**不要用于论文正文图**（印刷后对比过强、灰度区分差）。

---

## 5. 版式与尺寸（和期刊栏宽对齐）

| 用途 | 宽度 | 说明 |
| --- | --- | --- |
| 单栏（多数期刊） | 85 mm ≈ 3.35 in | 最小字号 7 pt 时仍要可读 |
| 双栏（通栏图） | 170 mm ≈ 6.7 in | 内容多时优先 |
| 幻灯片 16:9 | 1600×900 px 之类 | 用高对比配色 |

栅格分辨率：

- 位图（PNG/JPG）：目标 300–600 dpi。用脚本的 `-Scale` 放大：单栏 85 mm @300 dpi ≈ 1004 px，若默认导出偏小就 `-Scale 2` 或 `-Scale 3`。
- 矢量（SVG/PDF）：与分辨率无关，投稿优先。

## 6. 统一外观的 Mermaid 头

```
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'11px','lineColor':'#333333','primaryColor':'#FFFFFF','primaryBorderColor':'#333333','primaryTextColor':'#1A1A1A'},'flowchart':{'curve':'linear','nodeSpacing':40,'rankSpacing':55,'padding':8}}}%%
```

- `theme:'base'` 关掉默认的彩色主题，否则你的 `classDef` 会和主题打架。
- `curve:'linear'` 让连线更"论文感"（正交/直线），比默认贝塞尔更干净。
- 字体写 `Helvetica, Arial, sans-serif`：Windows 上会落到 Arial，和正文一致。

## 7. draw.io 侧的统一外观

- 关闭阴影：`shadow=0`
- 关闭 HTML 标签：`html=0`（避免导出后字体、粗细和编辑器显示不一致）
- 圆角克制：论文图多用 `rounded=0`，系统框图可用 `rounded=1`
- 统一字体：`fontFamily=Helvetica;fontSize=11`
- 线宽：普通 1.0–1.2，强调 1.4–1.6，不要出现 2 以上（缩放后会显得粗笨）
- 箭头：`endArrow=block;endFill=1` 或 `endArrow=classic`
- 容器/泳道：`swimlane;startSize=23;fillColor=#F5F7FA;strokeColor=#D6E4F0;`

## 8. 交付前自检（6 条）

1. 转成灰度后，各块是否仍能区分（明度差 ≥ 20%）？
2. 最小字号 ≥ 7 pt（按目标宽度换算后）？
3. 线条 ≥ 0.25 pt，且没有阴影、渐变、发光？
4. 颜色之外是否有第二编码（形状/线型/标签）？
5. 文字没有溢出图框、没有被连线穿过？
6. 图中不含截图、位图徽标或外部字体依赖（用系统自带 Helvetica/Arial）？
