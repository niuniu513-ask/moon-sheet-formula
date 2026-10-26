///|
/// Argument accessor that treats missing trailing arguments as blanks.
fn arg(args : Array[@value.Value], i : Int) -> @value.Value {
  if i < args.length() {
    args[i]
  } else {
    @value.Blank
  }
}

///|
/// First error found in any scalar cell of any argument, so functions can
/// propagate spreadsheet errors before doing arithmetic.
fn first_error(args : Array[@value.Value]) -> @value.Value? {
  for a in args {
    for cell in a.flatten() {
      match cell {
        @value.Err(e) => return Some(@value.Err(e))
        _ => ()
      }
    }
  }
  None
}

///|
/// Numeric coercion that rejects errors and grids.
fn as_num(v : @value.Value) -> Double? {
  match v {
    @value.Err(_) | @value.Grid(_) => None
    _ => v.number()
  }
}

///|
/// Collect the numeric cells of all arguments. Text cells are ignored, which is
/// how aggregate functions treat text inside a referenced range.
fn numeric_cells(args : Array[@value.Value]) -> Array[Double] {
  let out : Array[Double] = []
  for a in args {
    for cell in a.flatten() {
      match cell {
        @value.Num(d) => out.push(d)
        @value.Bool(b) => out.push(if b { 1.0 } else { 0.0 })
        _ => ()
      }
    }
  }
  out
}

///|
fn ok_number(d : Double) -> @value.Value {
  @value.number_value(d)
}

///|
fn bad_value() -> @value.Value {
  @value.Err(@value.ValueError)
}

///|
fn bad_num() -> @value.Value {
  @value.Err(@value.BadNum)
}

///|
fn pow10(digits : Int) -> Double {
  let mut f = 1.0
  let mut i = 0
  let n = if digits < 0 { -digits } else { digits }
  while i < n {
    f = f * 10.0
    i = i + 1
  }
  if digits < 0 {
    1.0 / f
  } else {
    f
  }
}

///|
fn round_away(x : Double, digits : Int) -> Double {
  let f = pow10(digits)
  let scaled = x * f
  let sign = if scaled < 0.0 { -1.0 } else { 1.0 }
  sign * (scaled.abs() + 0.5).floor() / f
}

///|
fn round_toward_zero(x : Double, digits : Int) -> Double {
  let f = pow10(digits)
  let scaled = x * f
  let sign = if scaled < 0.0 { -1.0 } else { 1.0 }
  sign * scaled.abs().floor() / f
}

///|
fn digits_arg(v : @value.Value) -> Int? {
  match as_num(v) {
    Some(d) => Some(d.to_int64().to_int())
    None => None
  }
}

///|
fn fn_sum(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let nums = numeric_cells(args)
      let mut total = 0.0
      for d in nums {
        total = total + d
      }
      ok_number(total)
    }
  }
}

///|
fn fn_product(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let nums = numeric_cells(args)
      if nums.length() == 0 {
        return ok_number(0.0)
      }
      let mut total = 1.0
      for d in nums {
        total = total * d
      }
      ok_number(total)
    }
  }
}

///|
fn fn_average(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let nums = numeric_cells(args)
      if nums.length() == 0 {
        return @value.Err(@value.DivZero)
      }
      let mut total = 0.0
      for d in nums {
        total = total + d
      }
      ok_number(total / nums.length().to_double())
    }
  }
}

///|
fn fn_min(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let nums = numeric_cells(args)
      if nums.length() == 0 {
        return ok_number(0.0)
      }
      let mut best = nums[0]
      for d in nums {
        if d < best {
          best = d
        }
      }
      ok_number(best)
    }
  }
}

///|
fn fn_max(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let nums = numeric_cells(args)
      if nums.length() == 0 {
        return ok_number(0.0)
      }
      let mut best = nums[0]
      for d in nums {
        if d > best {
          best = d
        }
      }
      ok_number(best)
    }
  }
}

///|
fn fn_count(args : Array[@value.Value]) -> @value.Value {
  let mut n = 0
  for a in args {
    for cell in a.flatten() {
      match cell {
        @value.Num(_) => n = n + 1
        _ => ()
      }
    }
  }
  ok_number(n.to_double())
}

///|
fn fn_counta(args : Array[@value.Value]) -> @value.Value {
  let mut n = 0
  for a in args {
    for cell in a.flatten() {
      match cell {
        @value.Blank => ()
        _ => n = n + 1
      }
    }
  }
  ok_number(n.to_double())
}

///|
fn fn_countblank(args : Array[@value.Value]) -> @value.Value {
  let mut n = 0
  for a in args {
    for cell in a.flatten() {
      match cell {
        @value.Blank => n = n + 1
        _ => ()
      }
    }
  }
  ok_number(n.to_double())
}

///|
fn sorted_nums(args : Array[@value.Value]) -> Array[Double] {
  let nums = numeric_cells(args)
  nums.sort()
  nums
}

///|
fn fn_median(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let nums = sorted_nums(args)
      let n = nums.length()
      if n == 0 {
        return bad_num()
      }
      if n % 2 == 1 {
        ok_number(nums[n / 2])
      } else {
        ok_number((nums[n / 2 - 1] + nums[n / 2]) / 2.0)
      }
    }
  }
}

///|
fn fn_large(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      if args.length() != 2 {
        return bad_value()
      }
      match as_num(args[1]) {
        None => bad_value()
        Some(k) => {
          let nums = sorted_nums([args[0]])
          let idx = k.to_int64().to_int()
          if idx < 1 || idx > nums.length() {
            return bad_num()
          }
          ok_number(nums[nums.length() - idx])
        }
      }
    }
  }
}

///|
fn fn_small(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      if args.length() != 2 {
        return bad_value()
      }
      match as_num(args[1]) {
        None => bad_value()
        Some(k) => {
          let nums = sorted_nums([args[0]])
          let idx = k.to_int64().to_int()
          if idx < 1 || idx > nums.length() {
            return bad_num()
          }
          ok_number(nums[idx - 1])
        }
      }
    }
  }
}

///|
fn unary_math(
  args : Array[@value.Value],
  f : (Double) -> Double,
) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Err(e) => @value.Err(e)
    _ =>
      match as_num(args[0]) {
        Some(d) => ok_number(f(d))
        None => bad_value()
      }
  }
}

///|
fn fn_abs(args : Array[@value.Value]) -> @value.Value {
  unary_math(args, fn(d) { d.abs() })
}

///|
fn fn_sign(args : Array[@value.Value]) -> @value.Value {
  unary_math(args, fn(d) {
    if d > 0.0 {
      1.0
    } else if d < 0.0 {
      -1.0
    } else {
      0.0
    }
  })
}

///|
fn fn_int(args : Array[@value.Value]) -> @value.Value {
  unary_math(args, fn(d) { d.floor() })
}

///|
fn fn_sqrt(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Err(e) => @value.Err(e)
    _ =>
      match as_num(args[0]) {
        Some(d) => if d < 0.0 { bad_num() } else { ok_number(d.sqrt()) }
        None => bad_value()
      }
  }
}

///|
fn fn_ln(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match as_num(arg(args, 0)) {
    Some(d) => if d <= 0.0 { bad_num() } else { ok_number(@math.ln(d)) }
    None => bad_value()
  }
}

///|
fn fn_exp(args : Array[@value.Value]) -> @value.Value {
  unary_math(args, fn(d) { @math.exp(d) })
}

///|
fn fn_log10(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match as_num(arg(args, 0)) {
    Some(d) => if d <= 0.0 { bad_num() } else { ok_number(@math.log10(d)) }
    None => bad_value()
  }
}

///|
fn fn_log(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let base = if args.length() == 2 { as_num(args[1]) } else { Some(10.0) }
  match (as_num(args[0]), base) {
    (Some(x), Some(b)) =>
      if x <= 0.0 || b <= 0.0 || b == 1.0 {
        bad_num()
      } else {
        ok_number(@math.ln(x) / @math.ln(b))
      }
    _ => bad_value()
  }
}

///|
fn fn_pi(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 0 {
    return bad_value()
  }
  ok_number(3.141592653589793)
}

///|
fn fn_power(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  match (as_num(args[0]), as_num(args[1])) {
    (Some(x), Some(y)) =>
      if x == 0.0 && y < 0.0 {
        @value.Err(@value.DivZero)
      } else {
        ok_number(@math.pow(x, y))
      }
    _ => bad_value()
  }
}

///|
fn fn_mod(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  match (as_num(args[0]), as_num(args[1])) {
    (Some(x), Some(y)) =>
      if y == 0.0 {
        @value.Err(@value.DivZero)
      } else {
        ok_number(x - y * (x / y).floor())
      }
    _ => bad_value()
  }
}

///|
fn fn_quotient(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  match (as_num(args[0]), as_num(args[1])) {
    (Some(x), Some(y)) =>
      if y == 0.0 {
        @value.Err(@value.DivZero)
      } else {
        ok_number((x / y).to_int64().to_double())
      }
    _ => bad_value()
  }
}

///|
fn fn_round(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let digits = if args.length() == 2 {
    match digits_arg(args[1]) {
      Some(d) => d
      None => return bad_value()
    }
  } else {
    0
  }
  match as_num(args[0]) {
    Some(x) => ok_number(round_away(x, digits))
    None => bad_value()
  }
}

///|
fn fn_roundup(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let digits = if args.length() == 2 {
    match digits_arg(args[1]) {
      Some(d) => d
      None => return bad_value()
    }
  } else {
    0
  }
  match as_num(args[0]) {
    Some(x) => {
      let f = pow10(digits)
      let scaled = x * f
      let sign = if scaled < 0.0 { -1.0 } else { 1.0 }
      ok_number(sign * scaled.abs().ceil() / f)
    }
    None => bad_value()
  }
}

///|
fn fn_rounddown(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let digits = if args.length() == 2 {
    match digits_arg(args[1]) {
      Some(d) => d
      None => return bad_value()
    }
  } else {
    0
  }
  match as_num(args[0]) {
    Some(x) => ok_number(round_toward_zero(x, digits))
    None => bad_value()
  }
}

///|
fn fn_ceiling(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let sig = if args.length() == 2 {
    match as_num(args[1]) {
      Some(s) => s
      None => return bad_value()
    }
  } else {
    1.0
  }
  match as_num(args[0]) {
    Some(x) => {
      if sig == 0.0 {
        return ok_number(0.0)
      }
      if x > 0.0 && sig < 0.0 {
        return bad_num()
      }
      let q = x / sig
      ok_number(q.ceil() * sig)
    }
    None => bad_value()
  }
}

///|
fn fn_floor(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let sig = if args.length() == 2 {
    match as_num(args[1]) {
      Some(s) => s
      None => return bad_value()
    }
  } else {
    1.0
  }
  match as_num(args[0]) {
    Some(x) => {
      if sig == 0.0 {
        return ok_number(0.0)
      }
      if x > 0.0 && sig < 0.0 {
        return bad_num()
      }
      let q = x / sig
      ok_number(q.floor() * sig)
    }
    None => bad_value()
  }
}

///|
fn fn_sumproduct(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      if args.length() == 0 {
        return bad_value()
      }
      let mut length = -1
      for a in args {
        let n = a.flatten().length()
        if length == -1 {
          length = n
        } else if n != length {
          return bad_value()
        }
      }
      let mut total = 0.0
      for i in 0..<length {
        let mut product = 1.0
        for a in args {
          let cell = a.flatten()[i]
          match cell {
            @value.Num(d) => product = product * d
            @value.Bool(b) => product = product * (if b { 1.0 } else { 0.0 })
            _ => product = product * 0.0
          }
        }
        total = total + product
      }
      ok_number(total)
    }
  }
}

///|
fn split_criteria(text : String) -> (String, String) {
  if text.length() >= 2 {
    if text[0:2].to_owned() == ">=" ||
      text[0:2].to_owned() == "<=" ||
      text[0:2].to_owned() == "<>" {
      return (text[0:2].to_owned(), @value.trim_ascii(text[2:].to_owned()))
    }
  }
  if text.length() >= 1 {
    let head = text[0:1].to_owned()
    if head == ">" || head == "<" || head == "=" {
      return (head, @value.trim_ascii(text[1:].to_owned()))
    }
  }
  ("=", @value.trim_ascii(text))
}

///|
fn apply_operator(op : String, cmp : Int) -> Bool {
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
/// Wildcard match supporting `*` and `?`, case-insensitive on ASCII.
fn wildcard_match(pattern : String, text : String) -> Bool {
  let p : Array[Char] = []
  for c in pattern {
    p.push(c.to_ascii_lowercase())
  }
  let t : Array[Char] = []
  for c in text {
    t.push(c.to_ascii_lowercase())
  }
  let mut pi = 0
  let mut ti = 0
  let mut star = -1
  let mut mark = 0
  while ti < t.length() {
    if pi < p.length() &&
      (p[pi].to_int() == 63 || p[pi].to_int() == t[ti].to_int()) {
      pi = pi + 1
      ti = ti + 1
    } else if pi < p.length() && p[pi].to_int() == 42 {
      star = pi
      mark = ti
      pi = pi + 1
    } else if star >= 0 {
      pi = star + 1
      mark = mark + 1
      ti = mark
    } else {
      return false
    }
  }
  while pi < p.length() && p[pi].to_int() == 42 {
    pi = pi + 1
  }
  pi == p.length()
}

///|
/// Criteria matching used by SUMIF/COUNTIF/AVERAGEIF: optional comparison
/// operator, numeric comparison when the remainder parses as a number,
/// otherwise case-insensitive text equality with `*` and `?` wildcards.
pub fn criteria_match(cell : @value.Value, criteria : @value.Value) -> Bool {
  match criteria {
    @value.Text(raw) => {
      let (op, rest) = split_criteria(@value.trim_ascii(raw))
      match @value.parse_number(rest) {
        Some(target) =>
          match cell.number() {
            Some(d) => {
              let cmp = if d < target { -1 } else if d > target { 1 } else { 0 }
              apply_operator(op, cmp)
            }
            None => false
          }
        None =>
          if op == "=" {
            wildcard_match(rest, cell.text())
          } else if op == "<>" {
            if rest == "" {
              !(cell is @value.Num(_) ||
              cell is @value.Text(_) ||
              cell is @value.Bool(_))
            } else {
              !wildcard_match(rest, cell.text())
            }
          } else {
            false
          }
      }
    }
    _ =>
      match @value.compare_value(cell, criteria) {
        Some(0) => true
        _ => false
      }
  }
}

///|
fn fn_sumif(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 2 || args.length() > 3 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let test_cells = args[0].flatten()
      let sum_cells = if args.length() == 3 {
        args[2].flatten()
      } else {
        test_cells
      }
      if test_cells.length() != sum_cells.length() {
        return bad_value()
      }
      let mut total = 0.0
      for i in 0..<test_cells.length() {
        if criteria_match(test_cells[i], args[1]) {
          match sum_cells[i] {
            @value.Num(d) => total = total + d
            @value.Bool(b) => total = total + (if b { 1.0 } else { 0.0 })
            _ => ()
          }
        }
      }
      ok_number(total)
    }
  }
}

///|
fn fn_countif(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let cells = args[0].flatten()
      let mut n = 0
      for c in cells {
        if criteria_match(c, args[1]) {
          n = n + 1
        }
      }
      ok_number(n.to_double())
    }
  }
}

///|
fn fn_averageif(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 2 || args.length() > 3 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let test_cells = args[0].flatten()
      let sum_cells = if args.length() == 3 {
        args[2].flatten()
      } else {
        test_cells
      }
      if test_cells.length() != sum_cells.length() {
        return bad_value()
      }
      let mut total = 0.0
      let mut n = 0
      for i in 0..<test_cells.length() {
        if criteria_match(test_cells[i], args[1]) {
          match sum_cells[i] {
            @value.Num(d) => {
              total = total + d
              n = n + 1
            }
            _ => ()
          }
        }
      }
      if n == 0 {
        @value.Err(@value.DivZero)
      } else {
        ok_number(total / n.to_double())
      }
    }
  }
}

///|
/// Shared implementation of the multi-criteria functions. In sum mode the first
/// argument is the value range and the rest are (range, criteria) pairs; in
/// count mode every argument after the first is part of a pair.
fn multi_criteria(args : Array[@value.Value], sum_mode : Bool) -> @value.Value {
  if sum_mode {
    if args.length() < 3 || args.length() % 2 == 0 {
      return bad_value()
    }
  } else if args.length() < 2 || args.length() % 2 != 0 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let value_cells = args[0].flatten()
      let pair_start = if sum_mode { 1 } else { 0 }
      let mut i = pair_start
      while i + 1 < args.length() {
        if args[i].flatten().length() != value_cells.length() {
          return bad_value()
        }
        i = i + 2
      }
      let mut total = 0.0
      let mut n = 0
      for row in 0..<value_cells.length() {
        let mut matched = true
        let mut j = pair_start
        while j + 1 < args.length() {
          let cells = args[j].flatten()
          if !criteria_match(cells[row], args[j + 1]) {
            matched = false
            break
          }
          j = j + 2
        }
        if matched {
          if sum_mode {
            match value_cells[row] {
              @value.Num(d) => {
                total = total + d
                n = n + 1
              }
              _ => ()
            }
          } else {
            n = n + 1
          }
        }
      }
      if sum_mode {
        ok_number(total)
      } else {
        ok_number(n.to_double())
      }
    }
  }
}

///|
fn fn_sumifs(args : Array[@value.Value]) -> @value.Value {
  multi_criteria(args, true)
}

///|
fn fn_countifs(args : Array[@value.Value]) -> @value.Value {
  multi_criteria(args, false)
}

///|
fn fn_averageifs(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 3 || args.length() % 2 == 0 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let value_cells = args[0].flatten()
      let mut total = 0.0
      let mut n = 0
      for row in 0..<value_cells.length() {
        let mut matched = true
        let mut j = 1
        while j + 1 < args.length() {
          let cells = args[j].flatten()
          if cells.length() != value_cells.length() {
            return bad_value()
          }
          if !criteria_match(cells[row], args[j + 1]) {
            matched = false
            break
          }
          j = j + 2
        }
        if matched {
          match value_cells[row] {
            @value.Num(d) => {
              total = total + d
              n = n + 1
            }
            _ => ()
          }
        }
      }
      if n == 0 {
        @value.Err(@value.DivZero)
      } else {
        ok_number(total / n.to_double())
      }
    }
  }
}

///|
/// Shared body of MAXIFS and MINIFS: keep the extreme numeric cell of the first
/// range among rows that satisfy every (criteria range, criteria) pair.
fn conditional_extreme(
  args : Array[@value.Value],
  want_max : Bool,
) -> @value.Value {
  if args.length() < 3 || args.length() % 2 == 0 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let value_cells = args[0].flatten()
      let mut i = 1
      while i + 1 < args.length() {
        if args[i].flatten().length() != value_cells.length() {
          return bad_value()
        }
        i = i + 2
      }
      let mut best : Double? = None
      for row in 0..<value_cells.length() {
        let mut matched = true
        let mut j = 1
        while j + 1 < args.length() {
          let cells = args[j].flatten()
          if !criteria_match(cells[row], args[j + 1]) {
            matched = false
            break
          }
          j = j + 2
        }
        if matched {
          match value_cells[row] {
            @value.Num(d) =>
              match best {
                None => best = Some(d)
                Some(cur) =>
                  if want_max {
                    if d > cur {
                      best = Some(d)
                    }
                  } else if d < cur {
                    best = Some(d)
                  }
              }
            _ => ()
          }
        }
      }
      match best {
        Some(d) => ok_number(d)
        None => ok_number(0.0)
      }
    }
  }
}

///|
fn fn_maxifs(args : Array[@value.Value]) -> @value.Value {
  conditional_extreme(args, true)
}

///|
fn fn_minifs(args : Array[@value.Value]) -> @value.Value {
  conditional_extreme(args, false)
}
