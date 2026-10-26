///|
/// Evaluation context: closures that resolve cell references and named ranges.
/// Keeping them as closures lets the workbook plug in its cache without the
/// evaluator depending on the workbook type.
pub struct EvalEnv {
  cell : (String, Int, Int) -> @value.Value
  name : (String) -> @value.Value
}

///|
fn is_comparison_op(op : String) -> Bool {
  match op {
    "=" | "<>" | "<" | "<=" | ">" | ">=" => true
    _ => false
  }
}

///|
fn apply_cmp(op : String, cmp : Int) -> Bool {
  match op {
    "=" => cmp == 0
    "<>" => cmp != 0
    ">" => cmp > 0
    ">=" => cmp >= 0
    "<" => cmp < 0
    "<=" => cmp <= 0
    _ => false
  }
}

///|
fn eval_arith(op : String, x : Double, y : Double) -> @value.Value {
  match op {
    "+" => @value.number_value(x + y)
    "-" => @value.number_value(x - y)
    "*" => @value.number_value(x * y)
    "/" =>
      if y == 0.0 {
        @value.Err(@value.DivZero)
      } else {
        @value.number_value(x / y)
      }
    "^" =>
      if x == 0.0 && y < 0.0 {
        @value.Err(@value.DivZero)
      } else {
        @value.number_value(@math.pow(x, y))
      }
    _ => @value.Err(@value.ValueError)
  }
}

///|
fn eval_binary(op : String, a : @value.Value, b : @value.Value) -> @value.Value {
  match (a, b) {
    (@value.Err(e), _) => @value.Err(e)
    (_, @value.Err(e)) => @value.Err(e)
    _ =>
      if op == "&" {
        match (a, b) {
          (@value.Grid(_), _) | (_, @value.Grid(_)) =>
            @value.Err(@value.ValueError)
          _ => @value.Text(a.text() + b.text())
        }
      } else if is_comparison_op(op) {
        match @value.compare_value(a, b) {
          Some(cmp) => @value.Bool(apply_cmp(op, cmp))
          None => @value.Err(@value.ValueError)
        }
      } else {
        match (a.number(), b.number()) {
          (Some(x), Some(y)) => eval_arith(op, x, y)
          _ => @value.Err(@value.ValueError)
        }
      }
  }
}

///|
fn values_equal_loose(a : @value.Value, b : @value.Value) -> Bool {
  if @value.Value::same(a, b) {
    return true
  }
  match @value.compare_value(a, b) {
    Some(0) => true
    _ => false
  }
}

///|
fn eval_if(args : Array[@syntax.Expr], env : EvalEnv) -> @value.Value {
  if args.length() < 2 || args.length() > 3 {
    return @value.Err(@value.ValueError)
  }
  let cond = eval_expr(args[0], env)
  match cond {
    @value.Err(e) => @value.Err(e)
    _ =>
      match cond.boolean() {
        Some(true) => eval_expr(args[1], env)
        Some(false) =>
          if args.length() == 3 {
            eval_expr(args[2], env)
          } else {
            @value.Bool(false)
          }
        None => @value.Err(@value.ValueError)
      }
  }
}

///|
fn eval_ifs(args : Array[@syntax.Expr], env : EvalEnv) -> @value.Value {
  if args.length() < 2 || args.length() % 2 != 0 {
    return @value.Err(@value.ValueError)
  }
  let mut i = 0
  while i + 1 < args.length() {
    let cond = eval_expr(args[i], env)
    match cond {
      @value.Err(e) => return @value.Err(e)
      _ =>
        match cond.boolean() {
          Some(true) => return eval_expr(args[i + 1], env)
          Some(false) => ()
          None => return @value.Err(@value.ValueError)
        }
    }
    i = i + 2
  }
  @value.Err(@value.NA)
}

///|
fn eval_iferror(
  args : Array[@syntax.Expr],
  env : EvalEnv,
  only_na : Bool,
) -> @value.Value {
  if args.length() != 2 {
    return @value.Err(@value.ValueError)
  }
  let first = eval_expr(args[0], env)
  match first {
    @value.Err(e) =>
      if only_na {
        match e {
          @value.NA => eval_expr(args[1], env)
          _ => @value.Err(e)
        }
      } else {
        eval_expr(args[1], env)
      }
    _ => first
  }
}

///|
fn eval_switch(args : Array[@syntax.Expr], env : EvalEnv) -> @value.Value {
  if args.length() < 3 {
    return @value.Err(@value.ValueError)
  }
  let target = eval_expr(args[0], env)
  match target {
    @value.Err(e) => @value.Err(e)
    _ => {
      let mut i = 1
      while i + 1 < args.length() {
        let candidate = eval_expr(args[i], env)
        if values_equal_loose(target, candidate) {
          return eval_expr(args[i + 1], env)
        }
        i = i + 2
      }
      // A trailing single argument is the default branch.
      if i < args.length() {
        eval_expr(args[i], env)
      } else {
        @value.Err(@value.NA)
      }
    }
  }
}

///|
fn eval_call(
  name : String,
  args : Array[@syntax.Expr],
  env : EvalEnv,
) -> @value.Value {
  match name {
    "IF" => eval_if(args, env)
    "IFS" => eval_ifs(args, env)
    "IFERROR" => eval_iferror(args, env, false)
    "IFNA" => eval_iferror(args, env, true)
    "SWITCH" => eval_switch(args, env)
    _ => {
      let values : Array[@value.Value] = []
      for a in args {
        values.push(eval_expr(a, env))
      }
      match @functions.call(name, values) {
        Some(v) => v
        None => @value.Err(@value.Name)
      }
    }
  }
}

///|
/// Evaluate a parsed expression against the environment.
pub fn eval_expr(expr : @syntax.Expr, env : EvalEnv) -> @value.Value {
  match expr {
    @syntax.Lit(v) => v
    @syntax.Ref(sheet, r, c) => (env.cell)(sheet, r, c)
    @syntax.Range(sheet, r1, c1, r2, c2) => {
      let r_lo = if r1 <= r2 { r1 } else { r2 }
      let r_hi = if r1 <= r2 { r2 } else { r1 }
      let c_lo = if c1 <= c2 { c1 } else { c2 }
      let c_hi = if c1 <= c2 { c2 } else { c1 }
      let size = (r_hi - r_lo + 1) * (c_hi - c_lo + 1)
      if size > 20000 {
        @value.Err(@value.Ref)
      } else {
        let rows : Array[Array[@value.Value]] = []
        for r in r_lo..<=r_hi {
          let row : Array[@value.Value] = []
          for c in c_lo..<=c_hi {
            row.push((env.cell)(sheet, r, c))
          }
          rows.push(row)
        }
        @value.Grid(rows)
      }
    }
    @syntax.NameLit(name) => (env.name)(@value.upper_ascii(name))
    @syntax.Call(name, args) => eval_call(name, args, env)
    @syntax.Unary(op, inner) => {
      let v = eval_expr(inner, env)
      match v {
        @value.Err(e) => @value.Err(e)
        _ =>
          if op == "%" {
            match v.number() {
              Some(d) => @value.number_value(d / 100.0)
              None => @value.Err(@value.ValueError)
            }
          } else if op == "-" {
            match v.number() {
              Some(d) => @value.number_value(-d)
              None => @value.Err(@value.ValueError)
            }
          } else {
            v
          }
      }
    }
    @syntax.Binary(op, left, right) => {
      let a = eval_expr(left, env)
      match a {
        @value.Err(e) => @value.Err(e)
        _ => {
          let b = eval_expr(right, env)
          eval_binary(op, a, b)
        }
      }
    }
  }
}

///|
/// Create an evaluation context from plain closures.
pub fn make_env(
  cell : (String, Int, Int) -> @value.Value,
  name : (String) -> @value.Value,
) -> EvalEnv {
  { cell, name, }
}
