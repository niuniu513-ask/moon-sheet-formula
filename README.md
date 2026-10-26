# moon-sheet-formula

纯 MoonBit 实现的电子表格公式引擎：把 `=SUM(A1:A3)*Tax` 这样的公式字符串，变成可计算、可增量重算、可定位错误的结果。

## 项目目标

电子表格的"算"这一步长期被文件格式掩盖：读写 `.xlsx` 的库很多，能把格子里那条公式真正按 Excel 语义算出结果的引擎很少。本项目只做计算层，并被设计成可以被上层表格程序直接调用：

- **解析**：词法分析 + 递归下降语法分析，覆盖单元格/区域/跨表/绝对引用、`+ - * / ^ &`、比较运算、一元负号与百分号、字符串字面量、函数嵌套。
- **求值**：Excel 兼容的值语义——数值、文本、布尔、空、错误值六种形态，以及它们之间的强制转换与错误传播规则。
- **函数库**：94 个内置函数，覆盖聚合、条件聚合、数学、文本、查找引用、日期、逻辑七类。
- **重算**：把公式之间的引用关系建成依赖图，做拓扑排序求值、整环循环检测、以及只重算受影响闭包的增量重算，并把失败原因变成带单元格地址的诊断信息。

## 与现有包的关系

Mooncakes 上与表格相关的包主要解决另外两件事：`moonbitlang/mbtexcel` 与 `bobzhang/spreadsheet` 负责 `.xlsx` 文件与单元格容器的读写，`FrozenLemonTee/LunarFormulas` 是单位化工程公式库。它们都不提供"公式求值 + 依赖重算"。本项目的输入是公式字符串与单元格内容，输出是值与诊断，因此可以接在任一 xlsx 读写之上，而不是替代它。

另有一批通用增量计算库（`bobzhang/incr`、`dowdiness/incr`、`illusory0x0/adapton`、`mizchi/ripple` 等）提供依赖追踪与记忆化，与本项目在"只重算受影响的部分"这一点上概念相邻。但它们是通用运行时，不含公式语法、A1 引用、Excel 值语义与函数库，也没有工作表/单元格模型；本项目的依赖图是为工作表场景专门写的一小段代码（脏闭包 + 拓扑序），不依赖这些库。详细的检索范围、关键词与逐包对比见 [SOURCES.md](SOURCES.md)。

## 特性一览

| 能力 | 说明 |
| --- | --- |
| 表达式语法 | 运算符优先级 6 级，`-2^2` 解析为 `-(2^2)`，与 Excel 一致 |
| 引用形态 | `A1`、`$A$1`、`A1:B3`、`'My Sheet'!B2`、`Data!A1:A3` |
| 值语义 | 数值/文本/布尔/空/错误/区域六种形态，含跨类型比较规则 |
| 错误值 | `#NULL!` `#DIV/0!` `#VALUE!` `#REF!` `#NAME?` `#NUM!` `#N/A` `#CIRCULAR!` |
| 函数库 | 94 个，`IF`/`IFS`/`IFERROR`/`IFNA`/`SWITCH` 惰性求值 |
| 依赖图 | DFS 拓扑排序，一次遍历完成求值顺序与循环检测 |
| 循环引用 | 整环标记，环上每个单元格都返回 `#CIRCULAR!` 并各留一条诊断 |
| 增量重算 | `recalculate_from(dirty)` 只重算脏单元格在下游的闭包 |
| 命名范围 | `define_name("Tax", "Rates!B1")`，大小写不敏感，支持矩形区域 |
| 确定性 | 节点与诊断排序，同样输入必得同样输出 |

## 安装前提

- MoonBit CLI：开发与验收使用 `moon 0.1.20260920`、`moonc v0.10.14`。
- 无第三方依赖，只用标准库 `moonbitlang/core`（`core/debug`、`core/math`）。
- 运行示例需要至少一个可用后端：`wasm-gc`（默认）、`js` 或 `native`。

## 快速开始

```bash
moon version --all
moon check --deny-warn --target all
moon test --deny-warn
moon run examples/demo --target wasm-gc
```

`moon test` 的实测结果：

```text
Total tests: 41, passed: 41, failed: 0.
```

`moon run examples/demo` 的前两段实测输出：

```text
=== moon-sheet-formula demo ===

[1] Budget sheet
  Coffee beans line         37.5
  Filter paper line         12
  Grinder line              89
  Grand total               138.5
  Average line (ROUND 2)    46.17
  Coffee subtotal (SUMIF)   37.5
  Total excl. tax (name)    122.57
  Days in 2026 (DAYS)       364
  Formatted total (TEXT)    138.50
  Guarded division          n/a

[2] Evaluation order of the first pass
  1.   Budget!D2
  2.   Budget!D3
  3.   Budget!D4
  4.   Budget!B7
  ...
  -> 10 formula cells, 0 diagnostics
```

## 使用方法

### 建工作簿并重算

```moonbit
let wb = @calc.Workbook::new()
let _ = wb.set_number("Budget", "B2", 3.0)   // 数量
let _ = wb.set_number("Budget", "C2", 12.5)  // 单价
let _ = wb.set_formula("Budget", "D2", "=B2*C2")
let _ = wb.set_number("Rates", "B1", 0.13)
let _ = wb.define_name("Tax", "Rates!B1")
let _ = wb.set_formula("Budget", "B7", "=SUM(D2:D4)")
let _ = wb.set_formula("Budget", "B10", "=ROUND(B7/(1+Tax), 2)")

let report = wb.recalculate()
println(wb.value_at("Budget", "B10").text())  // 122.57
println(report.diagnostics.length().to_string())  // 0
```

`set_*` 返回 `Result[Unit, CalcError]`：`InvalidReference`、`UnknownSheet`、`BadArea`、`DuplicateName`、`UnknownName`。单元格级的问题不会让写入失败，而是在重算时进入 `report.diagnostics`。

### 增量重算

```moonbit
let _ = wb.set_number("Budget", "B2", 12.0)
let report = wb.recalculate_from(["Budget!B2"])
println(report.order.length().to_string())        // 只有受影响的 7 个公式
println(wb.value_at("Budget", "B7").text())       // 251
```

`report.order` 是本次真正求值的单元格顺序，可直接当作审计轨迹；未被波及的公式沿用上一次的值。

### 直接求一条公式

```moonbit
// 在 "Budget" 表的上下文里求值，不进入依赖图
let v = wb.evaluate_formula("Budget", "=SUM(D2:D4)/3")
```

### 读取诊断

```moonbit
for d in report.diagnostics {
  println(d.cell + ": " + d.message)   // 例如 Risky!A1: circular reference
}
```

### 两种失败风格

项目对两类失败给了不同形状，调用方不需要额外适配：

- **解析失败用错误效应**：`@syntax.parse(text) -> Expr raise ParseError`，`@syntax.lex`、`@syntax.parse_a1`、`@syntax.parse_area` 同理。写解析器时错误直接向上传播，测试里用 `try?` 或 `catch` 转成数据，不需要层层拆 `Result`。
- **写入被拒用 `Result`**：`wb.set_number(...) -> Result[Unit, CalcError]`，因为"这格写不进去"是调用方要判断的普通数据，不是异常；`CalcError` 因此是普通枚举而不是 `suberror`。重算内部只在 `calc/syntax_bridge.mbt` 一处把错误效应转回数据，其余代码看到的都是值。

## 支持的函数（94 个）

| 分类 | 数量 | 函数 |
| --- | --- | --- |
| 聚合与统计 | 11 | `SUM`, `PRODUCT`, `AVERAGE`, `MIN`, `MAX`, `COUNT`, `COUNTA`, `COUNTBLANK`, `MEDIAN`, `LARGE`, `SMALL` |
| 条件聚合 | 8 | `SUMIF`, `SUMIFS`, `COUNTIF`, `COUNTIFS`, `AVERAGEIF`, `AVERAGEIFS`, `MAXIFS`, `MINIFS` |
| 数学 | 19 | `ABS`, `SIGN`, `INT`, `TRUNC`, `SQRT`, `LN`, `LOG`, `LOG10`, `EXP`, `PI`, `POWER`, `MOD`, `QUOTIENT`, `ROUND`, `ROUNDUP`, `ROUNDDOWN`, `CEILING`, `FLOOR`, `SUMPRODUCT` |
| 文本 | 18 | `LEN`, `LEFT`, `RIGHT`, `MID`, `TRIM`, `UPPER`, `LOWER`, `PROPER`, `CONCAT`, `CONCATENATE`, `TEXTJOIN`, `FIND`, `SEARCH`, `SUBSTITUTE`, `REPT`, `VALUE`, `TEXT`, `EXACT` |
| 查找与引用 | 9 | `VLOOKUP`, `HLOOKUP`, `LOOKUP`, `INDEX`, `MATCH`, `CHOOSE`, `RANK`, `ROWS`, `COLUMNS` |
| 日期 | 8 | `DATE`, `YEAR`, `MONTH`, `DAY`, `DAYS`, `EDATE`, `EOMONTH`, `WEEKDAY` |
| 逻辑与判断 | 21 | `IF`, `IFS`, `IFERROR`, `IFNA`, `SWITCH`, `AND`, `OR`, `NOT`, `XOR`, `TRUE`, `FALSE`, `NA`, `N`, `ISBLANK`, `ISNUMBER`, `ISTEXT`, `ISLOGICAL`, `ISERROR`, `ISNA`, `ISEVEN`, `ISODD` |

条件聚合函数的 criteria 支持 `> >= < <= <> =` 前缀、`*` 与 `?` 通配符，以及文本/数值自动判别；文本比较不区分大小写。

## 语义约定

这些选择决定了"算出来的数字是否和 Excel 一致"，逐条列出便于核对：

| 场景 | 行为 |
| --- | --- |
| 空单元格参与算术 | 视为 0，例如 `=空+5` 得 5 |
| 空单元格参与文本连接 | 视为空串 |
| 文本参与算术 | `#VALUE!`；但 `VALUE` 认的文本（含 `%`、指数）会被 `number()` 接受 |
| 聚合函数遇到文本 | 在区域内忽略，不污染求和结果 |
| 布尔参与算术 | `TRUE` → 1，`FALSE` → 0 |
| 比较不同类型 | 数值 < 文本 < 布尔；文本比较不区分 ASCII 大小写 |
| 除以 0 | `#DIV/0!`；`0^负数` 同 |
| 运算溢出或 NaN | `#NUM!` |
| 错误传播 | 任何参数是错误值时，该错误优先向外传播（`IFERROR`/`IFNA` 除外） |
| 循环引用 | 环上每个单元格一律 `#CIRCULAR!`，不迭代 |
| 未知函数或名称 | `#NAME?` |
| 引用不存在的表 | `#REF!` |
| 区域规模上限 | 单个区域超过 20000 个单元格时拒绝展开并给出诊断 |
| 日期 | 1900 日期序列，`DATE(1970,1,1)` = 25569 |
| 数字显示 | 最短往返十进制，`12.5` 而不是 `12.500000` |

## 依赖图与重算

1. `build_nodes`：遍历所有 `Formula` 单元格，解析出 AST，并把引用、区域、命名范围展开成规范键 `SHEET!A1`（区域按矩形展开，超过上限则记一条问题）。
2. `topo_sort`：对公式单元格做 DFS，出栈顺序即求值顺序；遇到指向栈内节点的边则判定成环，并把栈上从目标到栈顶的整段都标为环成员——这保证 `A1=B1, B1=A1` 中两个单元格都被标记，而不是只报一个。
3. `recalc_internal`：按顺序求值，值写入缓存；`recalculate_from` 先用反向表 `dependents` 从脏单元格求出下游闭包，只重算闭包内节点，其余沿用上次的值。
4. 求值失败的单元格得到相应错误值并追加 `Diagnostic`，整次重算不中断。

复杂度：依赖收集与拓扑排序均为 O(V+E)；全量重算一次遍历；增量重算的代价与受影响闭包大小成正比。

## 包结构

| 包 | 职责 | 对外 API |
| --- | --- | --- |
| `value` | 值类型、错误码、显示、比较、文本与数字解析 | `Value`、`ErrorCode`、`compare_value`、`parse_number` |
| `syntax` | 词法、语法、AST、A1 记号工具 | `lex`、`parse`、`parse_a1`、`parse_area`（均 `raise ParseError`）、`cell_a1`、`column_letters` |
| `functions` | 94 个函数与分发表 | `call`、`names`、`known`、`is_lazy`、`criteria_match` |
| `calc` | 工作簿模型、求值环境、依赖图与重算 | `Workbook`、`CellInput`、`CalcReport`、`Diagnostic`、`recalculate`、`recalculate_from` |
| `examples/demo` | 端到端示例（预算表 + 破坏性单元格） | `moon run` |

## 测试

```text
value     6  个：值语义、比较、数字与文本解析
syntax    7  个：词法、优先级、错误位置、A1 反解
functions 14 个：聚合、条件、文本、查找、日期、逻辑
calc     14 个：拓扑顺序、循环、增量、命名范围、跨表、错误传播
合计     41 个
```

CI 配置见 `.github/workflows/ci.yml`：在 `ubuntu-latest` 上安装 MoonBit（当前实测 `moonc v0.10.17`），依次执行

1. `moon check --deny-warn --target all`、`moon build --target all`、`moon test --deny-warn --target all`——四个目标各 41 个测试；
2. `moon info` 后 `git diff --exit-code`，拦截生成接口漂移；
3. `moon fmt --check` 作为**非阻断**报告：格式化器的输出会随工具链版本变化，把它做成阻断项会让版本差异伪装成代码问题；
4. 在 `wasm`、`wasm-gc`、`js`、`native` 上各跑一遍 `examples/demo`。

提交的 `pkg.generated.mbti` 以 CI 使用的工具链为准（该版本把 `Int` 渲染为 `Int32`），本地更旧的工具链重新运行 `moon info` 会显示同样的差异。

## 限制与不做的部分

明确写出来，避免误用：

- **不解析、不生成 `.xlsx`**：文件格式请交给 `mbtexcel` 之类的包，本引擎只吃公式字符串与单元格内容。
- **不做格式**：无字体、颜色、边框、条件格式、数字格式化（`TEXT` 只支持 `#,##0`、`0`、`0.00`、`0%` 这类子集）。
- **不支持数组公式与动态数组**：没有溢出语义，也没有隐式交集；区域只在函数参数位置有效。
- **不支持迭代计算**：循环引用一律报错，不提供"最多迭代 N 次"的收敛模式。
- **不支持 3D 引用**：`Sheet1:Sheet3!A1` 未实现。
- **不复刻 1900 闰年 bug**：1900-03-01 之前的历史日期与 Excel 有 1 天差异，这是有意选择。
- **浮点直接使用 IEEE 754 双精度**：没有 Excel 那套"15 位有效数字后修补"的显示修正，`0.1+0.2` 得到的是双精度结果，仅在显示层做最短往返格式化。
- **单线程、内存内**：整个工作簿常驻内存，没有分页或外部存储。

## 许可证

MIT，见 [LICENSE](LICENSE)。
