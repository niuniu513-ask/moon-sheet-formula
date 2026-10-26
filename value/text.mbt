///|
/// Uppercase ASCII letters only; other characters are copied unchanged. Used
/// for case-insensitive function-name lookup.
pub fn upper_ascii(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    sb.write_char(c.to_ascii_uppercase())
  }
  sb.to_string()
}

///|
/// ASCII-only trim used before parsing text numbers and booleans.
pub fn trim_ascii(s : String) -> String {
  let units = s.code_units()
  let n = units.length()
  let mut start = 0
  while start < n && is_space(units[start]) {
    start = start + 1
  }
  let mut end = n
  while end > start && is_space(units[end - 1]) {
    end = end - 1
  }
  build_ascii_range(units, start, end)
}

///|
fn is_space(u : UInt16) -> Bool {
  let v = u.to_int()
  v == 32 || v == 9 || v == 10 || v == 13
}

///|
fn build_ascii_range(
  units : ArrayView[UInt16],
  start : Int,
  end : Int,
) -> String {
  let sb = StringBuilder()
  let mut i = start
  while i < end {
    sb.write_char(Int::unsafe_to_char(units[i].to_int()))
    i = i + 1
  }
  sb.to_string()
}

///|
fn digit_at(units : ArrayView[UInt16], i : Int) -> Int {
  let v = units[i].to_int()
  if v >= 48 && v <= 57 {
    v - 48
  } else {
    -1
  }
}

///|
/// Parse the numeric text forms a spreadsheet accepts when text meets
/// arithmetic: optional spaces, optional sign, digits with an optional
/// fraction, an optional exponent and an optional trailing percent sign.
/// Anything else (currency symbols, grouping separators, units) yields None.
pub fn parse_number(text : String) -> Double? {
  let units = text.code_units()
  let n = units.length()
  let mut i = 0
  while i < n && is_space(units[i]) {
    i = i + 1
  }
  let mut negative = false
  if i < n && (units[i].to_int() == 45 || units[i].to_int() == 43) {
    negative = units[i].to_int() == 45
    i = i + 1
  }
  let mut mantissa = 0.0
  let mut digits = 0
  while i < n && digit_at(units, i) >= 0 {
    mantissa = mantissa * 10.0 + digit_at(units, i).to_double()
    digits = digits + 1
    i = i + 1
  }
  let mut scale = 1.0
  if i < n && units[i].to_int() == 46 {
    i = i + 1
    while i < n && digit_at(units, i) >= 0 {
      mantissa = mantissa * 10.0 + digit_at(units, i).to_double()
      scale = scale * 10.0
      digits = digits + 1
      i = i + 1
    }
  }
  if digits == 0 {
    return None
  }
  let mut exponent = 0
  if i < n && (units[i].to_int() == 101 || units[i].to_int() == 69) {
    i = i + 1
    let mut exponent_sign = 1
    if i < n && (units[i].to_int() == 45 || units[i].to_int() == 43) {
      if units[i].to_int() == 45 {
        exponent_sign = -1
      }
      i = i + 1
    }
    let mut exponent_digits = 0
    while i < n && digit_at(units, i) >= 0 {
      if exponent < 400 {
        exponent = exponent * 10 + digit_at(units, i)
      }
      exponent_digits = exponent_digits + 1
      i = i + 1
    }
    if exponent_digits == 0 {
      return None
    }
    exponent = exponent * exponent_sign
  }
  let mut percent = false
  if i < n && units[i].to_int() == 37 {
    percent = true
    i = i + 1
  }
  while i < n && is_space(units[i]) {
    i = i + 1
  }
  if i != n {
    return None
  }
  let mut result = mantissa / scale
  if negative {
    result = -result
  }
  if percent {
    result = result / 100.0
  }
  if exponent > 0 {
    let mut k = 0
    while k < exponent && k < 400 {
      result = result * 10.0
      k = k + 1
    }
  } else if exponent < 0 {
    let mut k = 0
    while k < -exponent && k < 400 {
      result = result / 10.0
      k = k + 1
    }
  }
  if result.is_nan() || result.is_inf() {
    None
  } else {
    Some(result)
  }
}
