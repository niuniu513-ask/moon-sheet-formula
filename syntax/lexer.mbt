///|
/// Token kinds produced by the formula lexer.
pub(all) enum TokenKind {
  Number(Double)
  StringLit(String)
  Name(String)
  Ref(Int, Int) // row, column (1-based)
  Sheet(String)
  Op(String)
  LParen
  RParen
  Comma
  Colon
  Bang
  End
} derive(Eq, Debug)

///|
pub extend TokenKind with Eq::{equal, not_equal}

///|
pub extend TokenKind with @debug.Debug::{to_repr}

///|
/// A token with its character offset in the formula text.
pub(all) struct Token {
  kind : TokenKind
  pos : Int
} derive(Eq, Debug)

///|
pub extend Token with Eq::{equal, not_equal}

///|
pub extend Token with @debug.Debug::{to_repr}

///|
fn is_digit(c : Char) -> Bool {
  let v = c.to_int()
  v >= 48 && v <= 57
}

///|
fn is_alpha(c : Char) -> Bool {
  let v = c.to_int()
  (v >= 65 && v <= 90) || (v >= 97 && v <= 122)
}

///|
fn is_word_char(c : Char) -> Bool {
  is_alpha(c) || is_digit(c) || c.to_int() == 95 || c.to_int() == 36
}

///|
fn chars_of(s : String) -> Array[Char] {
  let out : Array[Char] = []
  for c in s {
    out.push(c)
  }
  out
}

///|
/// Recognise an A1-style cell reference, with optional absolute markers, and
/// return its 1-based (row, column). Anything that is not a legal reference
/// (for example a function name) yields None.
pub fn cell_ref_of(word : String) -> (Int, Int)? {
  let cs = chars_of(word)
  let n = cs.length()
  if n == 0 {
    return None
  }
  let mut i = 0
  if cs[0].to_int() == 36 {
    i = 1
  }
  let letters_start = i
  while i < n && is_alpha(cs[i]) {
    i = i + 1
  }
  let letter_count = i - letters_start
  if letter_count < 1 || letter_count > 3 {
    return None
  }
  if i < n && cs[i].to_int() == 36 {
    i = i + 1
  }
  let digits_start = i
  while i < n && is_digit(cs[i]) {
    i = i + 1
  }
  let digit_count = i - digits_start
  if digit_count < 1 || digit_count > 7 {
    return None
  }
  if i != n {
    return None
  }
  let mut col = 0
  for k in letters_start..<(letters_start + letter_count) {
    col = col * 26 + (cs[k].to_ascii_uppercase().to_int() - 64)
  }
  let mut row = 0
  for k in digits_start..<(digits_start + digit_count) {
    row = row * 10 + (cs[k].to_int() - 48)
  }
  if col < 1 || col > 16384 || row < 1 || row > 1048576 {
    return None
  }
  Some((row, col))
}

///|
/// Tokenize formula text. Raises `ParseError` for unterminated strings,
/// malformed numbers and characters outside the supported grammar.
pub fn lex(input : String) -> Array[Token] raise ParseError {
  let cs = chars_of(input)
  let n = cs.length()
  let out : Array[Token] = []
  let mut i = 0
  while i < n {
    let c = cs[i]
    let v = c.to_int()
    if v == 32 || v == 9 || v == 10 || v == 13 {
      i = i + 1
      continue
    }
    // String literal, "" escapes a quote.
    if v == 34 {
      let start = i
      i = i + 1
      let sb = StringBuilder()
      let mut closed = false
      while i < n {
        if cs[i].to_int() == 34 {
          if i + 1 < n && cs[i + 1].to_int() == 34 {
            sb.write_char('"')
            i = i + 2
          } else {
            closed = true
            i = i + 1
            break
          }
        } else {
          sb.write_char(cs[i])
          i = i + 1
        }
      }
      if !closed {
        raise Unexpected("unterminated string literal", start)
      }
      out.push({ kind: StringLit(sb.to_string()), pos: start, })
      continue
    }
    // Quoted sheet name: 'My Sheet'!
    if v == 39 {
      let start = i
      i = i + 1
      let sb = StringBuilder()
      let mut closed = false
      while i < n {
        if cs[i].to_int() == 39 {
          if i + 1 < n && cs[i + 1].to_int() == 39 {
            sb.write_char('\'')
            i = i + 2
          } else {
            closed = true
            i = i + 1
            break
          }
        } else {
          sb.write_char(cs[i])
          i = i + 1
        }
      }
      if !closed {
        raise Unexpected("unterminated quoted sheet name", start)
      }
      out.push({ kind: Sheet(sb.to_string()), pos: start, })
      continue
    }
    // Number literal.
    if is_digit(c) || (v == 46 && i + 1 < n && is_digit(cs[i + 1])) {
      let start = i
      let sb = StringBuilder()
      while i < n && is_digit(cs[i]) {
        sb.write_char(cs[i])
        i = i + 1
      }
      if i < n && cs[i].to_int() == 46 {
        sb.write_char('.')
        i = i + 1
        while i < n && is_digit(cs[i]) {
          sb.write_char(cs[i])
          i = i + 1
        }
      }
      if i < n && (cs[i].to_int() == 101 || cs[i].to_int() == 69) {
        sb.write_char('e')
        i = i + 1
        if i < n && (cs[i].to_int() == 43 || cs[i].to_int() == 45) {
          sb.write_char(cs[i])
          i = i + 1
        }
        while i < n && is_digit(cs[i]) {
          sb.write_char(cs[i])
          i = i + 1
        }
      }
      let text = sb.to_string()
      match @value.parse_number(text) {
        Some(d) => out.push({ kind: Number(d), pos: start, })
        None => raise BadNumber(text, start)
      }
      continue
    }
    // Identifier, cell reference or sheet name.
    if is_alpha(c) || v == 36 || v == 95 {
      let start = i
      let sb = StringBuilder()
      while i < n && is_word_char(cs[i]) {
        sb.write_char(cs[i])
        i = i + 1
      }
      let word = sb.to_string()
      if i < n && cs[i].to_int() == 33 {
        out.push({ kind: Sheet(word), pos: start, })
        out.push({ kind: Bang, pos: i, })
        i = i + 1
        continue
      }
      match cell_ref_of(word) {
        Some(rc) => out.push({ kind: Ref(rc.0, rc.1), pos: start, })
        None => out.push({ kind: Name(word), pos: start, })
      }
      continue
    }
    match v {
      40 => {
        out.push({ kind: LParen, pos: i, })
        i = i + 1
      }
      41 => {
        out.push({ kind: RParen, pos: i, })
        i = i + 1
      }
      44 | 59 => {
        out.push({ kind: Comma, pos: i, })
        i = i + 1
      }
      58 => {
        out.push({ kind: Colon, pos: i, })
        i = i + 1
      }
      33 => {
        out.push({ kind: Bang, pos: i, })
        i = i + 1
      }
      43 | 45 | 42 | 47 | 94 | 38 | 37 | 61 => {
        out.push({ kind: Op(c.to_string()), pos: i, })
        i = i + 1
      }
      60 =>
        if i + 1 < n && cs[i + 1].to_int() == 62 {
          out.push({ kind: Op("<>"), pos: i, })
          i = i + 2
        } else if i + 1 < n && cs[i + 1].to_int() == 61 {
          out.push({ kind: Op("<="), pos: i, })
          i = i + 2
        } else {
          out.push({ kind: Op("<"), pos: i, })
          i = i + 1
        }
      62 =>
        if i + 1 < n && cs[i + 1].to_int() == 61 {
          out.push({ kind: Op(">="), pos: i, })
          i = i + 2
        } else {
          out.push({ kind: Op(">"), pos: i, })
          i = i + 1
        }
      _ => raise Unexpected("unsupported character `" + c.to_string() + "`", i)
    }
  }
  out.push({ kind: End, pos: n, })
  out
}
