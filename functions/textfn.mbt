///|
fn chars_of_string(s : String) -> Array[Char] {
  let out : Array[Char] = []
  for c in s {
    out.push(c)
  }
  out
}

///|
fn join_chars(cs : Array[Char], start : Int, end : Int) -> String {
  let sb = StringBuilder()
  let mut i = start
  while i < end && i < cs.length() {
    sb.write_char(cs[i])
    i = i + 1
  }
  sb.to_string()
}

///|
/// Case-sensitive substring search over characters. Returns a 0-based index.
fn index_of_chars(
  hay : Array[Char],
  needle : Array[Char],
  from : Int,
  ignore_case : Bool,
) -> Int? {
  if needle.length() == 0 {
    return Some(from)
  }
  let mut i = from
  while i + needle.length() <= hay.length() {
    let mut j = 0
    let mut same = true
    while j < needle.length() {
      let a = if ignore_case {
        hay[i + j].to_ascii_lowercase().to_int()
      } else {
        hay[i + j].to_int()
      }
      let b = if ignore_case {
        needle[j].to_ascii_lowercase().to_int()
      } else {
        needle[j].to_int()
      }
      if a != b {
        same = false
        break
      }
      j = j + 1
    }
    if same {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn fn_len(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match args[0] {
    @value.Err(e) => @value.Err(e)
    _ => ok_number(chars_of_string(args[0].text()).length().to_double())
  }
}

///|
fn fn_left(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let cs = chars_of_string(arg(args, 0).text())
  let n = if args.length() == 2 {
    match as_num(args[1]) {
      Some(d) => d.to_int64().to_int()
      None => return bad_value()
    }
  } else {
    1
  }
  if n < 0 {
    return bad_value()
  }
  let take = if n > cs.length() { cs.length() } else { n }
  @value.Text(join_chars(cs, 0, take))
}

///|
fn fn_right(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 1 || args.length() > 2 {
    return bad_value()
  }
  let cs = chars_of_string(arg(args, 0).text())
  let n = if args.length() == 2 {
    match as_num(args[1]) {
      Some(d) => d.to_int64().to_int()
      None => return bad_value()
    }
  } else {
    1
  }
  if n < 0 {
    return bad_value()
  }
  let take = if n > cs.length() { cs.length() } else { n }
  @value.Text(join_chars(cs, cs.length() - take, cs.length()))
}

///|
fn fn_mid(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 3 {
    return bad_value()
  }
  let cs = chars_of_string(args[0].text())
  let start = match as_num(args[1]) {
    Some(d) => d.to_int64().to_int()
    None => return bad_value()
  }
  let len = match as_num(args[2]) {
    Some(d) => d.to_int64().to_int()
    None => return bad_value()
  }
  if start < 1 || len < 0 {
    return bad_value()
  }
  let begin = start - 1
  let mut end = begin + len
  if begin > cs.length() {
    return @value.Text("")
  }
  if end > cs.length() {
    end = cs.length()
  }
  @value.Text(join_chars(cs, begin, end))
}

///|
/// Excel TRIM: strip leading and trailing spaces and collapse internal runs to
/// a single space.
fn fn_trim(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  let cs = chars_of_string(args[0].text())
  let sb = StringBuilder()
  let mut i = 0
  let mut pending_space = false
  let mut started = false
  while i < cs.length() {
    let v = cs[i].to_int()
    if v == 32 || v == 9 || v == 10 || v == 13 {
      if started {
        pending_space = true
      }
    } else {
      if pending_space {
        sb.write_char(' ')
        pending_space = false
      }
      sb.write_char(cs[i])
      started = true
    }
    i = i + 1
  }
  @value.Text(sb.to_string())
}

///|
fn fn_upper(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  let sb = StringBuilder()
  for c in args[0].text() {
    sb.write_char(c.to_ascii_uppercase())
  }
  @value.Text(sb.to_string())
}

///|
fn fn_lower(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  let sb = StringBuilder()
  for c in args[0].text() {
    sb.write_char(c.to_ascii_lowercase())
  }
  @value.Text(sb.to_string())
}

///|
fn fn_concat(args : Array[@value.Value]) -> @value.Value {
  match first_error(args) {
    Some(e) => e
    None => {
      let sb = StringBuilder()
      for a in args {
        for cell in a.flatten() {
          match cell {
            @value.Err(_) => ()
            _ => sb.write_string(cell.text())
          }
        }
      }
      @value.Text(sb.to_string())
    }
  }
}

///|
fn fn_textjoin(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 3 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let delim = args[0].text()
      let ignore_empty = match args[1].boolean() {
        Some(b) => b
        None => return bad_value()
      }
      let parts : Array[String] = []
      let mut i = 2
      while i < args.length() {
        for cell in args[i].flatten() {
          let t = cell.text()
          if ignore_empty && t == "" {
            continue
          }
          parts.push(t)
        }
        i = i + 1
      }
      let sb = StringBuilder()
      let mut k = 0
      while k < parts.length() {
        if k > 0 {
          sb.write_string(delim)
        }
        sb.write_string(parts[k])
        k = k + 1
      }
      @value.Text(sb.to_string())
    }
  }
}

///|
fn fn_find_impl(args : Array[@value.Value], ignore_case : Bool) -> @value.Value {
  if args.length() < 2 || args.length() > 3 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let needle = chars_of_string(args[0].text())
      let hay = chars_of_string(args[1].text())
      let start = if args.length() == 3 {
        match as_num(args[2]) {
          Some(d) => d.to_int64().to_int()
          None => return bad_value()
        }
      } else {
        1
      }
      if start < 1 {
        return bad_value()
      }
      match index_of_chars(hay, needle, start - 1, ignore_case) {
        Some(idx) => ok_number((idx + 1).to_double())
        None => bad_value()
      }
    }
  }
}

///|
fn fn_find(args : Array[@value.Value]) -> @value.Value {
  fn_find_impl(args, false)
}

///|
fn fn_search(args : Array[@value.Value]) -> @value.Value {
  fn_find_impl(args, true)
}

///|
fn fn_substitute(args : Array[@value.Value]) -> @value.Value {
  if args.length() < 3 || args.length() > 4 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let source = args[0].text()
      let old = args[1].text()
      let replacement = args[2].text()
      let instance = if args.length() == 4 {
        match as_num(args[3]) {
          Some(d) => d.to_int64().to_int()
          None => return bad_value()
        }
      } else {
        0
      }
      if instance < 0 {
        return bad_value()
      }
      if old == "" {
        return @value.Text(source)
      }
      let cs = chars_of_string(source)
      let needle = chars_of_string(old)
      let sb = StringBuilder()
      let mut i = 0
      let mut seen = 0
      while i < cs.length() {
        let hit = index_of_chars(cs, needle, i, false)
        match hit {
          Some(idx) =>
            if idx == i {
              seen = seen + 1
              if instance == 0 || instance == seen {
                sb.write_string(replacement)
              } else {
                sb.write_string(old)
              }
              i = i + needle.length()
            } else {
              sb.write_char(cs[i])
              i = i + 1
            }
          None => {
            sb.write_char(cs[i])
            i = i + 1
          }
        }
      }
      @value.Text(sb.to_string())
    }
  }
}

///|
fn fn_rept(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let s = args[0].text()
      let n = match as_num(args[1]) {
        Some(d) => d.to_int64().to_int()
        None => return bad_value()
      }
      if n < 0 {
        return bad_value()
      }
      if s.length() * n > 1000000 {
        return bad_value()
      }
      @value.Text(s.repeat(n))
    }
  }
}

///|
fn fn_value(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match @value.parse_number(args[0].text()) {
    Some(d) => ok_number(d)
    None => bad_value()
  }
}

///|
/// Minimal number-format subset for TEXT: `#,##0`, `0`, `0.00`, `0.000`,
/// `0%`, `0.0%` and the same patterns without grouping. Anything else falls
/// back to the plain shortest representation.
fn format_fixed(d : Double, fmt : String) -> String {
  let cs = chars_of_string(fmt)
  let mut percent = false
  let mut grouping = false
  let mut decimals = 0
  let mut seen_dot = false
  let mut valid = true
  for c in cs {
    let v = c.to_int()
    if v == 37 {
      percent = true
    } else if v == 44 {
      grouping = true
    } else if v == 46 {
      seen_dot = true
    } else if v == 48 {
      if seen_dot {
        decimals = decimals + 1
      }
    } else if v == 35 {
      // '#' accepted as a placeholder
      ()
    } else {
      valid = false
    }
  }
  if !valid {
    return @value.format_number(d)
  }
  let scaled = if percent { d * 100.0 } else { d }
  if scaled.abs() >= 1.0e15 {
    return @value.format_number(d)
  }
  let f = pow10(decimals)
  let magnitude = scaled.abs()
  let rounded = (magnitude * f + 0.5).floor()
  let total = rounded.to_int64()
  let unit = f.to_int64()
  let int_part = (total / unit).to_string()
  let frac_part = if decimals > 0 {
    (total % unit).to_string().pad_start(decimals, '0')
  } else {
    ""
  }
  let grouped = if grouping {
    let digits : Array[Char] = []
    for c in int_part {
      digits.push(c)
    }
    let sb = StringBuilder()
    let mut i = 0
    while i < digits.length() {
      if i > 0 && (digits.length() - i) % 3 == 0 {
        sb.write_char(',')
      }
      sb.write_char(digits[i])
      i = i + 1
    }
    sb.to_string()
  } else {
    int_part
  }
  let sign = if scaled < 0.0 { "-" } else { "" }
  let body = if decimals > 0 { grouped + "." + frac_part } else { grouped }
  if percent {
    sign + body + "%"
  } else {
    sign + body
  }
}

///|
fn fn_text(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None =>
      match as_num(args[0]) {
        Some(d) => @value.Text(format_fixed(d, args[1].text()))
        None => @value.Text(args[0].text())
      }
  }
}

///|
fn fn_exact(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 2 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => @value.Bool(args[0].text() == args[1].text())
  }
}

///|
fn proper_upper(c : Char) -> Char {
  let v = c.to_int()
  if v >= 97 && v <= 122 {
    Int::unsafe_to_char(v - 32)
  } else {
    c
  }
}

///|
fn proper_lower(c : Char) -> Char {
  let v = c.to_int()
  if v >= 65 && v <= 90 {
    Int::unsafe_to_char(v + 32)
  } else {
    c
  }
}

///|
/// PROPER: uppercase the first letter of each word and lowercase the rest.
fn fn_proper(args : Array[@value.Value]) -> @value.Value {
  if args.length() != 1 {
    return bad_value()
  }
  match first_error(args) {
    Some(e) => e
    None => {
      let sb = StringBuilder()
      let mut prev_alnum = false
      for c in chars_of_string(args[0].text()) {
        let v = c.to_int()
        let is_alpha = (v >= 65 && v <= 90) || (v >= 97 && v <= 122)
        let is_digit = v >= 48 && v <= 57
        if is_alpha {
          sb.write_char(
            if prev_alnum {
              proper_lower(c)
            } else {
              proper_upper(c)
            },
          )
        } else {
          sb.write_char(c)
        }
        prev_alnum = is_alpha || is_digit
      }
      @value.Text(sb.to_string())
    }
  }
}
