///|
fn rows_of(v : @value.Value) -> Array[Array[@value.Value]] {
  match v {
    @value.Grid(rs) => rs
    _ => [[v]]
  }
}

///|
fn fn_vlookup(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 3 || args.length() > 4 {
    return bad_value()
  }
  match first_error([args[0], args[2], arg(args, 3)]) {
    Some(e) => e
    None => {
      let lookup = args[0]
      let rows = rows_of(args[1])
      let col_index = match as_num(args[2]) {
        Some(d) => d.to_int64().to_int()
        None => return bad_value()
      }
      let approximate = if args.length() == 4 {
        match args[3].boolean() {
          Some(b) => b
          None => return bad_value()
        }
      } else {
        true
      }
      if rows.length() == 0 {
        return @value.Err(@value.NA)
      }
      let width = rows[0].length()
      if col_index < 1 || col_index > width {
        return @value.Err(@value.Ref)
      }
      let mut best = -1
      for i in 0..<rows.length() {
        if rows[i].length() < width {
          continue
        }
        match @value.compare_value(rows[i][0], lookup) {
          Some(cmp) =>
            if cmp == 0 {
              return rows[i][col_index - 1]
            } else if approximate && cmp < 0 {
              best = i
            }
          None => ()
        }
      }
      if approximate && best >= 0 {
        rows[best][col_index - 1]
      } else {
        @value.Err(@value.NA)
      }
    }
  }
}

///|
fn fn_hlookup(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 3 || args.length() > 4 {
    return bad_value()
  }
  match first_error([args[0], args[2], arg(args, 3)]) {
    Some(e) => e
    None => {
      let lookup = args[0]
      let rows = rows_of(args[1])
      let row_index = match as_num(args[2]) {
        Some(d) => d.to_int64().to_int()
        None => return bad_value()
      }
      let approximate = if args.length() == 4 {
        match args[3].boolean() {
          Some(b) => b
          None => return bad_value()
        }
      } else {
        true
      }
      if rows.length() == 0 || row_index < 1 || row_index > rows.length() {
        return @value.Err(@value.Ref)
      }
      let header = rows[0]
      let mut best = -1
      for c in 0..<header.length() {
        match @value.compare_value(header[c], lookup) {
          Some(cmp) =>
            if cmp == 0 {
              if row_index - 1 < rows.length() &&
                c < rows[row_index - 1].length() {
                return rows[row_index - 1][c]
              }
            } else if approximate && cmp < 0 {
              best = c
            }
          None => ()
        }
      }
      let pick = if approximate { best } else { -1 }
      if pick >= 0 && pick < rows[row_index - 1].length() {
        rows[row_index - 1][pick]
      } else {
        @value.Err(@value.NA)
      }
    }
  }
}

///|
fn fn_index(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 2 || args.length() > 3 {
    return bad_value()
  }
  match first_error([args[1], arg(args, 2)]) {
    Some(e) => e
    None => {
      let rows = rows_of(args[0])
      if rows.length() == 0 {
        return @value.Err(@value.Ref)
      }
      let row_index = match as_num(args[1]) {
        Some(d) => d.to_int64().to_int()
        None => return bad_value()
      }
      let width = rows[0].length()
      let col_index = if args.length() == 3 {
        match as_num(args[2]) {
          Some(d) => d.to_int64().to_int()
          None => return bad_value()
        }
      } else if rows.length() == 1 {
        row_index
      } else {
        1
      }
      let effective_row = if rows.length() == 1 && args.length() == 2 {
        1
      } else {
        row_index
      }
      if effective_row < 1 || effective_row > rows.length() {
        return @value.Err(@value.Ref)
      }
      if col_index < 1 ||
        col_index > width ||
        col_index > rows[effective_row - 1].length() {
        return @value.Err(@value.Ref)
      }
      rows[effective_row - 1][col_index - 1]
    }
  }
}

///|
fn fn_match(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 2 || args.length() > 3 {
    return bad_value()
  }
  match first_error([args[0], arg(args, 2)]) {
    Some(e) => e
    None => {
      let lookup = args[0]
      let cells = args[1].flatten()
      let match_type = if args.length() == 3 {
        match as_num(args[2]) {
          Some(d) => d.to_int64().to_int()
          None => return bad_value()
        }
      } else {
        1
      }
      if match_type == 0 {
        for i in 0..<cells.length() {
          match @value.compare_value(cells[i], lookup) {
            Some(0) => return ok_number((i + 1).to_double())
            _ => ()
          }
        }
        return @value.Err(@value.NA)
      }
      let mut best = -1
      for i in 0..<cells.length() {
        match @value.compare_value(cells[i], lookup) {
          Some(cmp) =>
            if match_type > 0 && cmp <= 0 {
              best = i
            } else if match_type < 0 && cmp >= 0 {
              best = i
            }
          None => ()
        }
      }
      if best >= 0 {
        ok_number((best + 1).to_double())
      } else {
        @value.Err(@value.NA)
      }
    }
  }
}

///|
fn fn_choose(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 2 {
    return bad_value()
  }
  match first_error([args[0]]) {
    Some(e) => e
    None =>
      match as_num(args[0]) {
        Some(d) => {
          let idx = d.to_int64().to_int()
          if idx < 1 || idx >= args.length() {
            bad_value()
          } else {
            args[idx]
          }
        }
        None => bad_value()
      }
  }
}

///|
fn fn_rows(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  ok_number(rows_of(args[0]).length().to_double())
}

///|
fn fn_columns(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  let rows = rows_of(args[0])
  if rows.length() == 0 {
    ok_number(0.0)
  } else {
    ok_number(rows[0].length().to_double())
  }
}

///|
/// RANK(number, ref, [order]): 1-based position of `number` among the numeric
/// cells of `ref`. Omitted or zero order ranks descending, as in Excel.
fn fn_rank(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 2 || args.length() > 3 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let target = match as_num(args[0]) {
        Some(d) => d
        None => return bad_value()
      }
      let ascending = if args.length() == 3 {
        match as_num(args[2]) {
          Some(d) => d != 0.0
          None => return bad_value()
        }
      } else {
        false
      }
      let mut seen = false
      let mut rank = 1
      // Only numeric cells take part in a ranking; text, blanks and booleans in
      // the reference are skipped, as in Excel.
      for cell in args[1].flatten() {
        match cell {
          @value.Num(d) =>
            if d == target {
              seen = true
            } else if ascending {
              if d < target {
                rank = rank + 1
              }
            } else if d > target {
              rank = rank + 1
            }
          _ => ()
        }
      }
      if seen {
        ok_number(rank.to_double())
      } else {
        @value.Err(@value.NA)
      }
    }
  }
}

///|
/// LOOKUP(value, vector, [result]): approximate match on an ascending vector.
/// Without a result vector the matched key is returned, matching Excel's
/// two-argument form.
fn fn_lookup(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 2 || args.length() > 3 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let lookup = args[0]
      let keys = args[1].flatten()
      let results = if args.length() == 3 {
        args[2].flatten()
      } else {
        keys.copy()
      }
      if results.length() != keys.length() {
        return @value.Err(@value.Ref)
      }
      let mut best = -1
      for i in 0..<keys.length() {
        match @value.compare_value(keys[i], lookup) {
          Some(cmp) =>
            if cmp == 0 {
              return results[i]
            } else if cmp < 0 {
              best = i
            }
          None => ()
        }
      }
      if best >= 0 {
        results[best]
      } else {
        @value.Err(@value.NA)
      }
    }
  }
}
