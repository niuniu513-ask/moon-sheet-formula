///|
/// One formula cell after parsing, with its dependencies resolved to keys.
priv struct FormulaNode {
  key : String
  sheet : String
  ast : @syntax.Expr?
  parse_error : String?
  deps : Array[String]
  name_error : String?
}

///|
const MAX_RANGE_CELLS : Int = 20000

///|
fn push_range_keys(
  sheet : String,
  r1 : Int,
  c1 : Int,
  r2 : Int,
  c2 : Int,
  out : Array[String],
  problems : Array[String],
) -> Unit {
  let rows = (if r1 <= r2 { r2 - r1 } else { r1 - r2 }) + 1
  let cols = (if c1 <= c2 { c2 - c1 } else { c1 - c2 }) + 1
  if rows * cols > MAX_RANGE_CELLS {
    problems.push(
      "range is larger than " + MAX_RANGE_CELLS.to_string() + " cells",
    )
    return
  }
  let r_lo = if r1 <= r2 { r1 } else { r2 }
  let r_hi = if r1 <= r2 { r2 } else { r1 }
  let c_lo = if c1 <= c2 { c1 } else { c2 }
  let c_hi = if c1 <= c2 { c2 } else { c1 }
  for r in r_lo..<=r_hi {
    for c in c_lo..<=c_hi {
      out.push(cell_key(sheet, r, c))
    }
  }
}

///|
fn collect_deps(
  expr : @syntax.Expr,
  own_sheet : String,
  names : Map[String, @syntax.Area],
  out : Array[String],
  problems : Array[String],
) -> Unit {
  match expr {
    @syntax.Lit(_) => ()
    @syntax.Ref(sheet, r, c) => {
      let target = if sheet == "" { own_sheet } else { sheet }
      out.push(cell_key(target, r, c))
    }
    @syntax.Range(sheet, r1, c1, r2, c2) => {
      let target = if sheet == "" { own_sheet } else { sheet }
      push_range_keys(target, r1, c1, r2, c2, out, problems)
    }
    @syntax.NameLit(name) => {
      let upper = @value.upper_ascii(name)
      match names.get(upper) {
        None => problems.push("unknown name `" + name + "`")
        Some(area) => {
          let target = if area.sheet == "" { own_sheet } else { area.sheet }
          push_range_keys(
            target,
            area.r1,
            area.c1,
            area.r2,
            area.c2,
            out,
            problems,
          )
        }
      }
    }
    @syntax.Call(_, args) =>
      for a in args {
        collect_deps(a, own_sheet, names, out, problems)
      }
    @syntax.Unary(_, inner) =>
      collect_deps(inner, own_sheet, names, out, problems)
    @syntax.Binary(_, l, r) => {
      collect_deps(l, own_sheet, names, out, problems)
      collect_deps(r, own_sheet, names, out, problems)
    }
  }
}

///|
fn Workbook::build_nodes(self : Workbook) -> Array[FormulaNode] {
  let nodes : Array[FormulaNode] = []
  for sheet_name, cells in self.sheets {
    for a1, input in cells {
      match input {
        Formula(text) =>
          match parse_a1_opt(a1) {
            None => ()
            Some(rc) => {
              let key = cell_key(sheet_name, rc.0, rc.1)
              match parse_expr_result(text) {
                Err(msg) =>
                  nodes.push({
                    key,
                    sheet: sheet_name,
                    ast: None,
                    parse_error: Some("formula failed to parse: " + msg),
                    deps: [],
                    name_error: None,
                  })
                Ok(ast) => {
                  let deps : Array[String] = []
                  let problems : Array[String] = []
                  collect_deps(ast, sheet_name, self.names, deps, problems)
                  let name_error = if problems.length() > 0 {
                    Some(problems[0])
                  } else {
                    None
                  }
                  nodes.push({
                    key,
                    sheet: sheet_name,
                    ast: Some(ast),
                    parse_error: None,
                    deps,
                    name_error,
                  })
                }
              }
            }
          }
        _ => ()
      }
    }
  }
  nodes.sort_by(fn(a, b) { a.key.lexical_compare(b.key) })
  nodes
}

///|
fn parse_error_text(e : @syntax.ParseError) -> String {
  match e {
    @syntax.Unexpected(msg, pos) => msg + " at offset " + pos.to_string()
    @syntax.UnexpectedEnd(pos) =>
      "unexpected end of formula at offset " + pos.to_string()
    @syntax.BadNumber(text, pos) =>
      "bad number `" + text + "` at offset " + pos.to_string()
    @syntax.EmptyFormula => "formula is empty"
  }
}

///|
/// Depth-first topological order with back-edge detection. Returns the order as
/// node indices plus a flag per node marking members of a dependency cycle.
fn topo_sort(nodes : Array[FormulaNode]) -> (Array[Int], Array[Bool]) {
  let n = nodes.length()
  let index : Map[String, Int] = Map([])
  for i in 0..<n {
    index[nodes[i].key] = i
  }
  let state : Array[Int] = Array::make(n, 0)
  let cyclic : Array[Bool] = Array::make(n, false)
  let order : Array[Int] = []
  for start in 0..<n {
    if state[start] != 0 {
      continue
    }
    let stack : Array[(Int, Int)] = [(start, 0)]
    state[start] = 1
    while stack.length() > 0 {
      let frame = stack[stack.length() - 1]
      let node_index = frame.0
      let dep_index = frame.1
      if dep_index < nodes[node_index].deps.length() {
        stack[stack.length() - 1] = (node_index, dep_index + 1)
        match index.get(nodes[node_index].deps[dep_index]) {
          Some(target) =>
            if state[target] == 0 {
              state[target] = 1
              stack.push((target, 0))
            } else if state[target] == 1 {
              // Back edge: the DFS stack holds the current path, so every frame
              // from `target` up to the top is a member of the same cycle.
              let mut k = 0
              let mut found = false
              while k < stack.length() && !found {
                if stack[k].0 == target {
                  found = true
                } else {
                  k = k + 1
                }
              }
              if found {
                for j in k..<stack.length() {
                  cyclic[stack[j].0] = true
                }
              } else {
                cyclic[target] = true
              }
            }
          None => ()
        }
      } else {
        state[node_index] = 2
        order.push(node_index)
        let _ = stack.pop()
      }
    }
  }
  (order, cyclic)
}

///|
/// Map from a dependency key to the formula cells that read it, used to find
/// the closure of cells affected by an edit.
fn build_dependents(nodes : Array[FormulaNode]) -> Map[String, Array[Int]] {
  let map : Map[String, Array[Int]] = Map([])
  for i in 0..<nodes.length() {
    for dep in nodes[i].deps {
      match map.get(dep) {
        Some(list) => list.push(i)
        None => map[dep] = [i]
      }
    }
  }
  map
}

///|
fn Workbook::cell_lookup(
  self : Workbook,
  computed : Map[String, @value.Value],
  sheet : String,
  row : Int,
  col : Int,
) -> @value.Value {
  let key = cell_key(sheet, row, col)
  match computed.get(key) {
    Some(v) => v
    None =>
      match self.sheets.get(sheet) {
        None => @value.Err(@value.Ref)
        Some(cells) =>
          match cells.get(@syntax.cell_a1(row, col)) {
            Some(Number(d)) => @value.Num(d)
            Some(CellText(t)) => @value.Text(t)
            Some(Boolean(b)) => @value.Bool(b)
            _ => @value.Blank
          }
      }
  }
}

///|
/// Value of a named range: a single cell collapses to a scalar, a rectangle
/// becomes a grid so functions such as SUM and VLOOKUP can consume it.
fn Workbook::name_lookup(
  self : Workbook,
  computed : Map[String, @value.Value],
  own_sheet : String,
  upper : String,
) -> @value.Value {
  match self.names.get(upper) {
    None => @value.Err(@value.Name)
    Some(area) => {
      let target = if area.sheet == "" { own_sheet } else { area.sheet }
      if !self.sheets.contains(target) {
        return @value.Err(@value.Ref)
      }
      let rows = area.r2 - area.r1 + 1
      let cols = area.c2 - area.c1 + 1
      if rows * cols > MAX_RANGE_CELLS {
        return @value.Err(@value.Ref)
      }
      if rows == 1 && cols == 1 {
        return self.cell_lookup(computed, target, area.r1, area.c1)
      }
      let grid : Array[Array[@value.Value]] = []
      for r in area.r1..<=area.r2 {
        let row : Array[@value.Value] = []
        for c in area.c1..<=area.c2 {
          row.push(self.cell_lookup(computed, target, r, c))
        }
        grid.push(row)
      }
      @value.Grid(grid)
    }
  }
}

///|
/// Recalculate every formula cell in dependency order.
pub fn Workbook::recalculate(self : Workbook) -> CalcReport {
  self.recalc_internal([])
}

///|
/// Recalculate only the cells affected by a set of edited `SHEET!A1` keys,
/// reusing the previous values for everything else.
pub fn Workbook::recalculate_from(
  self : Workbook,
  dirty : Array[String],
) -> CalcReport {
  self.recalc_internal(dirty)
}

///|
fn Workbook::recalc_internal(
  self : Workbook,
  dirty : Array[String],
) -> CalcReport {
  let nodes = self.build_nodes()
  let (order, cyclic) = topo_sort(nodes)
  let index : Map[String, Int] = Map([])
  for i in 0..<nodes.length() {
    index[nodes[i].key] = i
  }
  let recompute : Array[Bool] = Array::make(nodes.length(), dirty.length() == 0)
  if dirty.length() > 0 {
    let dependents = build_dependents(nodes)
    let pending : Array[String] = []
    for d in dirty {
      pending.push(d)
    }
    let seen : Map[String, Bool] = Map([])
    while pending.length() > 0 {
      let key = pending.pop().unwrap()
      if seen.contains(key) {
        continue
      }
      seen[key] = true
      match index.get(key) {
        Some(j) => recompute[j] = true
        None => ()
      }
      match dependents.get(key) {
        Some(list) =>
          for j in list {
            if !seen.contains(nodes[j].key) {
              pending.push(nodes[j].key)
            }
          }
        None => ()
      }
    }
  }
  let computed : Map[String, @value.Value] = Map([])
  if dirty.length() > 0 {
    for k, v in self.last {
      computed[k] = v
    }
  }
  let diagnostics : Array[Diagnostic] = []
  let evaluated : Array[String] = []
  for i in order {
    if !recompute[i] {
      continue
    }
    let node = nodes[i]
    evaluated.push(node.key)
    let value = if cyclic[i] {
      diagnostics.push({ cell: node.key, message: "circular reference", })
      @value.Err(@value.Circular)
    } else {
      match node.parse_error {
        Some(msg) => {
          diagnostics.push({ cell: node.key, message: msg, })
          @value.Err(@value.ValueError)
        }
        None =>
          match node.ast {
            None => @value.Err(@value.ValueError)
            Some(ast) =>
              match node.name_error {
                Some(msg) => {
                  diagnostics.push({ cell: node.key, message: msg, })
                  @value.Err(@value.Name)
                }
                None => {
                  let sheet = node.sheet
                  let env = make_env(
                    fn(s, r, c) {
                      let target = if s == "" { sheet } else { s }
                      self.cell_lookup(computed, target, r, c)
                    },
                    fn(nm) { self.name_lookup(computed, sheet, nm) },
                  )
                  eval_expr(ast, env)
                }
              }
          }
      }
    }
    computed[node.key] = value
  }
  self.last = computed
  // Sort so the report is stable regardless of traversal order.
  diagnostics.sort_by(fn(a, b) { a.cell.lexical_compare(b.cell) })
  { values: computed, diagnostics, order: evaluated, }
}

///|
/// Dependencies of one cell, as canonical `SHEET!A1` keys. Empty for constants
/// and for formulas that do not parse.
pub fn Workbook::dependencies(
  self : Workbook,
  sheet : String,
  a1 : String,
) -> Array[String] {
  let out : Array[String] = []
  match parse_a1_opt(a1) {
    None => out
    Some(rc) => {
      let key = cell_key(sheet, rc.0, rc.1)
      for node in self.build_nodes() {
        if node.key == key {
          for d in node.deps {
            out.push(d)
          }
        }
      }
      out
    }
  }
}

///|
/// Evaluate a standalone formula in the context of one sheet, against the
/// values of the last recalculation, without adding it to the dependency graph.
pub fn Workbook::evaluate_formula(
  self : Workbook,
  sheet : String,
  formula : String,
) -> @value.Value {
  match parse_expr_result(formula) {
    Err(_) => @value.Err(@value.ValueError)
    Ok(ast) => {
      let env = make_env(
        fn(s, r, c) {
          let target = if s == "" { sheet } else { s }
          self.cell_lookup(self.last, target, r, c)
        },
        fn(nm) { self.name_lookup(self.last, sheet, nm) },
      )
      eval_expr(ast, env)
    }
  }
}
