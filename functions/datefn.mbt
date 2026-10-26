///|
/// Serial number of 1970-01-01 in the spreadsheet date system, whose day zero
/// is 1899-12-30. Dates before 1900-03-01 are not adjusted for the historical
/// 1900 leap-year bug; see README.
const EPOCH_SERIAL : Int64 = 25569L

///|
fn floor_div(a : Int, b : Int) -> Int {
  let q = a / b
  if a % b != 0 && (a < 0) != (b < 0) {
    q - 1
  } else {
    q
  }
}

///|
fn floor_mod(a : Int, b : Int) -> Int {
  a - floor_div(a, b) * b
}

///|
fn days_from_civil(y : Int, m : Int, d : Int) -> Int64 {
  let y0 = (if m <= 2 { y - 1 } else { y }).to_int64()
  let era = (if y0 >= 0L { y0 } else { y0 - 399L }) / 400L
  let yoe = y0 - era * 400L
  let mp = (if m > 2 { m - 3 } else { m + 9 }).to_int64()
  let doy = (153L * mp + 2L) / 5L + d.to_int64() - 1L
  let doe = yoe * 365L + yoe / 4L - yoe / 100L + doy
  era * 146097L + doe - 719468L
}

///|
fn civil_from_days(z : Int64) -> (Int, Int, Int) {
  let z2 = z + 719468L
  let era = (if z2 >= 0L { z2 } else { z2 - 146096L }) / 146097L
  let doe = z2 - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let mut y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = mp + (if mp < 10L { 3L } else { -9L })
  y = y + (if m <= 2L { 1L } else { 0L })
  (y.to_int(), m.to_int(), d.to_int())
}

///|
fn serial_of_civil(y : Int, m : Int, d : Int) -> Int64 {
  days_from_civil(y, m, d) + EPOCH_SERIAL
}

///|
fn int_arg(args : Array[@value.Value], i : Int) -> Int? {
  match as_num(arg(args, i)) {
    Some(d) => Some(d.to_int64().to_int())
    None => None
  }
}

///|
fn fn_date(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 3 {
    return bad_value()
  }
  match (int_arg(args, 0), int_arg(args, 1), int_arg(args, 2)) {
    (Some(y), Some(m), Some(d)) => {
      let adj = m - 1
      let year = y + floor_div(adj, 12)
      let month = floor_mod(adj, 12) + 1
      let serial = serial_of_civil(year, month, 1) + d.to_int64() - 1L
      if serial < 0L {
        bad_num()
      } else {
        ok_number(serial.to_double())
      }
    }
    _ => bad_value()
  }
}

///|
fn serial_parts(v : @value.Value) -> (Int, Int, Int)? {
  match as_num(v) {
    Some(d) => {
      let serial = d.floor().to_int64()
      if serial < 0L {
        return None
      }
      let (y, m, day) = civil_from_days(serial - EPOCH_SERIAL)
      Some((y, m, day))
    }
    None => None
  }
}

///|
fn fn_year(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match serial_parts(args[0]) {
    Some((y, _, _)) => ok_number(y.to_double())
    None => bad_num()
  }
}

///|
fn fn_month(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match serial_parts(args[0]) {
    Some((_, m, _)) => ok_number(m.to_double())
    None => bad_num()
  }
}

///|
fn fn_day(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match serial_parts(args[0]) {
    Some((_, _, d)) => ok_number(d.to_double())
    None => bad_num()
  }
}

///|
fn fn_days(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  match (as_num(args[0]), as_num(args[1])) {
    (Some(end), Some(start)) => ok_number(end.floor() - start.floor())
    _ => bad_value()
  }
}

///|
fn days_in_month(y : Int, m : Int) -> Int {
  let first = days_from_civil(y, m, 1)
  let (ny, nm) = if m == 12 { (y + 1, 1) } else { (y, m + 1) }
  (days_from_civil(ny, nm, 1) - first).to_int()
}

///|
fn fn_edate(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  let months = match int_arg(args, 1) {
    Some(m) => m
    None => return bad_value()
  }
  match serial_parts(args[0]) {
    Some((y, m, d)) => {
      let total = y * 12 + (m - 1) + months
      let year = floor_div(total, 12)
      let month = floor_mod(total, 12) + 1
      let limit = days_in_month(year, month)
      let day = if d > limit { limit } else { d }
      ok_number(serial_of_civil(year, month, day).to_double())
    }
    None => bad_num()
  }
}

///|
/// WEEKDAY(serial, [type]): 1-based weekday of a date serial. Type 1 is the
/// Excel default (Sunday = 1); type 2 starts the week on Monday at 1, type 3 on
/// Monday at 0.
fn fn_weekday(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let kind = if args.length() == 2 {
    match int_arg(args, 1) {
      Some(k) => k
      None => return bad_value()
    }
  } else {
    1
  }
  match as_num(args[0]) {
    Some(d) => {
      let serial = d.floor().to_int64()
      if serial < 0L {
        return bad_num()
      }
      // 1970-01-01 (serial 25569) was a Thursday, so index 4 of a Sunday-based
      // week is the anchor.
      let day_index = floor_mod((serial - EPOCH_SERIAL).to_int() + 4, 7)
      if kind == 1 {
        ok_number((day_index + 1).to_double())
      } else if kind == 2 {
        ok_number((if day_index == 0 { 7 } else { day_index }).to_double())
      } else if kind == 3 {
        ok_number((if day_index == 0 { 6 } else { day_index - 1 }).to_double())
      } else {
        bad_num()
      }
    }
    None => bad_value()
  }
}

///|
/// EOMONTH(serial, months): last day of the month `months` away from the start.
fn fn_eomonth(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  let months = match int_arg(args, 1) {
    Some(m) => m
    None => return bad_value()
  }
  match serial_parts(args[0]) {
    Some((y, m, _)) => {
      let total = y * 12 + (m - 1) + months
      let year = floor_div(total, 12)
      let month = floor_mod(total, 12) + 1
      let serial = serial_of_civil(year, month, days_in_month(year, month))
      if serial < 0L {
        bad_num()
      } else {
        ok_number(serial.to_double())
      }
    }
    None => bad_num()
  }
}
