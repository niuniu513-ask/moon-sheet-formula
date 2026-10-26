///|
fn fn_isblank(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Grid(_) => @value.Bool(false)
    _ => @value.Bool(args[0] is @value.Blank)
  }
}

///|
fn fn_isnumber(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Num(_) => @value.Bool(true)
    _ => @value.Bool(false)
  }
}

///|
fn fn_istext(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Text(_) => @value.Bool(true)
    _ => @value.Bool(false)
  }
}

///|
fn fn_islogical(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Bool(_) => @value.Bool(true)
    _ => @value.Bool(false)
  }
}

///|
fn fn_iserror(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  @value.Bool(args[0].is_error())
}

///|
fn fn_isna(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Err(e) =>
      match e {
        @value.NA => @value.Bool(true)
        _ => @value.Bool(false)
      }
    _ => @value.Bool(false)
  }
}

///|
fn fn_na(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 0 {
    return bad_value()
  }
  @value.Err(@value.NA)
}

///|
fn fn_n(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Err(e) => @value.Err(e)
    @value.Num(d) => ok_number(d)
    @value.Bool(b) => ok_number(if b { 1.0 } else { 0.0 })
    @value.Text(_) => ok_number(0.0)
    @value.Blank => ok_number(0.0)
    @value.Grid(rows) =>
      if rows.length() > 0 && rows[0].length() > 0 {
        fn_n([rows[0][0]])
      } else {
        ok_number(0.0)
      }
  }
}

///|
fn fn_not(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Err(e) => @value.Err(e)
    _ =>
      match args[0].boolean() {
        Some(b) => @value.Bool(!b)
        None => bad_value()
      }
  }
}

///|
fn fn_true(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 0 {
    return bad_value()
  }
  @value.Bool(true)
}

///|
fn fn_false(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 0 {
    return bad_value()
  }
  @value.Bool(false)
}

///|
fn fn_xor(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let mut trues = 0
      for a in args {
        for cell in a.flatten() {
          match cell {
            @value.Bool(b) => if b { trues = trues + 1 }
            @value.Num(d) => if d != 0.0 { trues = trues + 1 }
            _ => ()
          }
        }
      }
      @value.Bool(trues % 2 == 1)
    }
  }
}

///|
/// Shared body of AND and OR: text and blank cells inside ranges are ignored,
/// as in Excel. With no logical value at all the result is #VALUE!.
fn logical_reduce(args : Array[@value.Value], want_all : Bool) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let mut any = false
      let mut acc = want_all
      for a in args {
        for cell in a.flatten() {
          match cell {
            @value.Bool(b) => {
              any = true
              if want_all {
                if !b {
                  acc = false
                }
              } else if b {
                acc = true
              }
            }
            @value.Num(d) => {
              any = true
              let truth = d != 0.0
              if want_all {
                if !truth {
                  acc = false
                }
              } else if truth {
                acc = true
              }
            }
            _ => ()
          }
        }
      }
      if any {
        @value.Bool(acc)
      } else {
        bad_value()
      }
    }
  }
}

///|
fn fn_and(args : Array[@value.Value]) -> @value.Value {
  logical_reduce(args, true)
}

///|
fn fn_or(args : Array[@value.Value]) -> @value.Value {
  logical_reduce(args, false)
}

///|
fn is_even_odd(args : Array[@value.Value], want_even : Bool) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None =>
      match as_num(args[0]) {
        Some(d) => {
          let n = d.to_int64()
          let even = n % 2L == 0L
          @value.Bool(if want_even { even } else { !even })
        }
        None => bad_value()
      }
  }
}

///|
fn fn_iseven(args : Array[@value.Value]) -> @value.Value {
  is_even_odd(args, true)
}

///|
fn fn_isodd(args : Array[@value.Value]) -> @value.Value {
  is_even_odd(args, false)
}
