# 查重与选题记录

记录时间：2026-10-26。原则：只写实际执行过的检索与可复查的结论；没有查到的部分明确标为"未核实"。

## 1. 检索范围

| 项目 | 内容 |
| --- | --- |
| Mooncakes 全量索引 | 本地快照 `topic-screening-index-20261016.json`，共 3040 个包（名称、版本、描述、关键词、仓库地址、创建时间） |
| 索引快照日期 | 2026-10-16 |
| 二次核对 | 2026-10-26 对 `incr` / `adapton` / `incremental` / `spreadsheet` / `formula` 等关键词重新过滤同一索引 |
| 网页检索 | 1 次定向检索 "MoonBit spreadsheet formula evaluation engine dependency recalculation github"（2026-10-26） |
| 范围限制 | 未逐仓阅读全部源码；未覆盖 Mooncakes 之外的私有仓库与未发布代码 |

## 2. 关键词与命中量

| 关键词组 | 命中包数 | 说明 |
| --- | --- | --- |
| `spreadsheet` / `xlsx` / `excel` / `worksheet` / `workbook` / `formula` / `电子表格` / `公式` / `单元格` / `求值` | 20 | 见下表的强相关包 |
| `incremental` / `incr` / `adapton` / `salsa` / `dependency` | 23 | 通用增量计算/依赖图运行时，其中 6 个是通用增量计算库，其余为增量备份、增量解析、增量打包等 |
| 组合词（公式 + 求值 + 重算） | 0 | 没有包同时声明公式语法解析、Excel 值语义与工作表依赖重算 |

## 3. 强相关包对比

| 包 | 它实际做的事 | 与本项目的关系 |
| --- | --- | --- |
| `moonbitlang/mbtexcel`、`bobzhang/mbtexcel` | Go excelize 的 MoonBit 移植，读写 `.xlsx` | 文件层，互补。本项目不碰文件格式，输入是公式字符串 |
| `bobzhang/spreadsheet` | 表格数据容器（索引中描述为空） | 容器层，互补。未核对源码，见"未核实项" |
| `bobzhang/office`、`bobzhang/office-lib` | 面向 Agent 的 XLSX/DOCX 命令行工具 | 工具层，互补 |
| `Lampese/office-viewer`、`vectie/moonleaf` | OOXML 只读浏览器/轻量编辑器 | 展示层，互补 |
| `sundaysebasidian-byte/moonods`、`zlhahaha/partsieve` | ODS 写出、OOXML 能力审计与重建 | 打包层，互补 |
| `t-ujiie-g/yxl` | YAML 驱动的 xlsx 编译器 | 生成层；是否包含公式求值未逐行核对 |
| `ZSeanYves/doc_parser`、`ZSeanYves/markitdown`、`R00TK17/moonreader` | 文档解析与转 Markdown | 与公式计算无关 |
| `FrozenLemonTee/LunarFormulas`、`formulas-calculator`、`formulas-calculator-web` | 基于 LunarUnits 的单位化工程公式对象与 CLI/网页 | "formula" 指工程公式，不是电子表格公式；无工作表、无依赖图 |
| `SupremeHuaji/MoonClmech` | 经典力学计算库（SymPy Mechanics 风格） | 领域计算库，无表格语义 |
| `dowdiness/incr`、`bobzhang/incr`、`illusory0x0/adapton`、`mizchi/ripple`、`starAndHonor/comemoon`、`sgy1023-crt/cassowary` | 通用增量计算/约束求解运行时（Salsa、Adapton、comemo 系） | **唯一有概念交集的组**：都做"依赖变了只重算受影响的部分"。但它们不含公式语法解析、A1 引用、Excel 值类型与错误值、函数库，也没有单元格/工作表模型；`incr` 的 README 用电子表格作比喻并有示例 demo，仍属通用框架 |
| `Zcxssxx/moon-ninja`、`123123213weqw/moon_taskforge`、`Lyhdsba/moonforge` | 构建调度器/任务 DAG 执行 | 依赖图用于任务编排，与工作表求值无关 |

## 4. 拟新增能力（与上述包均不重叠的部分）

1. 电子表格公式的**词法与语法**：运算符优先级、`-2^2` 的一元运算结合、`$A$1` 绝对引用、`'My Sheet'!B2` 引号表名、跨表区域。
2. **Excel 兼容值语义**：六种值形态、跨类型比较序（数值 < 文本 < 布尔）、空单元格按 0、文本数字转换、错误值传播。
3. **94 个函数的函数库**与惰性求值分支（`IF`/`IFS`/`IFERROR`/`IFNA`/`SWITCH` 不预求值未选中的分支）。
4. **工作表级依赖图**：以 `SHEET!A1` 为键收集引用（区域展开、命名范围展开）、DFS 拓扑排序、整环循环标记、脏闭包增量重算、带单元格地址的诊断。
5. **可复现的工程交付**：41 个测试、`wasm-gc`/`js`/`native` 三目标构建与测试、CI、`moon run` 示例。

## 5. 复用接口

- 只用标准库 `moonbitlang/core`（`core/debug`、`core/math`），无第三方依赖。
- 不复制任何现有包的代码；A1 记号、序列日期换算等均为本项目自行实现。
- 与 xlsx 库的衔接方式是数据级而非代码级：由调用方把单元格内容喂给 `Workbook::set_*`。

## 6. 验证证据

| 项目 | 命令 | 结果 |
| --- | --- | --- |
| 全目标检查 | `moon check --deny-warn --target all` | 通过，0 警告 |
| 全目标构建 | `moon build --target all` | 通过（wasm / wasm-gc / js / native） |
| 全目标测试 | `moon test --deny-warn --target all` | 四个目标各 41/41 通过 |
| 格式 | `moon fmt --check` | 通过 |
| 示例 | `moon run examples/demo --target wasm-gc` | 正常输出预算表与诊断 |
| 线上 CI | GitHub Actions 运行 40326485260 | 通过：check/build/test 四目标、接口一致性、四个后端运行示例 |
| 仓库状态 | 24 个提交，公开仓库 `niuniu513-ask/moon-sheet-formula` | 默认分支 main，工作树干净 |

## 7. 未核实项

- `bobzhang/spreadsheet` 索引描述为空，未读源码，无法确认其是否包含任何公式处理逻辑，仅按名称与调用方式判断为单元格/表格容器。
- `t-ujiie-g/yxl` 是否在生成 xlsx 时对公式字符串做求值未核对；按描述它把 YAML 编译成 xlsx，求值应在 Excel 一侧发生。
- `dowdiness/incr` 的示例 demo 覆盖到什么程度的表格语义未逐文件核对；其公开说明是通用增量计算框架。
- 网页检索只做了 1 次定向查询，未穷尽 GitHub 全站；"未发现同能力项目"仅指上述检索范围内未发现。
