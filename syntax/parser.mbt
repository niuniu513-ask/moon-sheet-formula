///|
/// Recursive-descent parser for spreadsheet formulas. Precedence follows Excel:
/// comparison < concatenation < addition < multiplication < power, with unary
/// minus binding tighter than `^` (so -2^2 evaluates as (-2)^2).
priv struct Parser {
  toks : Array[Token]
  mut pos : Int
  mut depth : Int
}

///|
fn Parser::peek(self : Parser) -> TokenKind {
  self.toks[self.pos].kind
}

///|
fn Parser::current_pos(self : Parser) -> Int {
  self.toks[self.pos].pos
}

///|
fn Parser::at_end(self : Parser) -> Bool {
  match self.peek() {
    End => true
    _ => false
  }
}

///|
fn is_op(kind : TokenKind, name : String) -> Bool {
  match kind {
    Op(o) => o == name
    _ => false
  }
}

///|
fn Expr::is_comparison_op(name : String) -> Bool {
  match name {
    "=" | "<>" | "<" | "<=" | ">" | ">=" => true
    _ => false
  }
}

///|
fn Parser::parse_comparison(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_concat()
  while true {
    let kind = self.peek()
    let matched = match kind {
      Op(o) => if Expr::is_comparison_op(o) { Some(o) } else { None }
      _ => None
    }
    match matched {
      Some(op) => {
        self.pos = self.pos + 1
        let right = self.parse_concat()
        left = Binary(op, left, right)
      }
      None => break
    }
  }
  left
}

///|
fn Parser::parse_concat(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_add()
  while is_op(self.peek(), "&") {
    self.pos = self.pos + 1
    let right = self.parse_add()
    left = Binary("&", left, right)
  }
  left
}

///|
fn Parser::parse_add(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_mul()
  while true {
    let kind = self.peek()
    let op = match kind {
      Op(o) => if o == "+" || o == "-" { Some(o) } else { None }
      _ => None
    }
    match op {
      Some(o) => {
        self.pos = self.pos + 1
        let right = self.parse_mul()
        left = Binary(o, left, right)
      }
      None => break
    }
  }
  left
}

///|
fn Parser::parse_mul(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_power()
  while true {
    let kind = self.peek()
    let op = match kind {
      Op(o) => if o == "*" || o == "/" { Some(o) } else { None }
      _ => None
    }
    match op {
      Some(o) => {
        self.pos = self.pos + 1
        let right = self.parse_power()
        left = Binary(o, left, right)
      }
      None => break
    }
  }
  left
}

///|
fn Parser::parse_power(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_unary()
  while is_op(self.peek(), "^") {
    self.pos = self.pos + 1
    let right = self.parse_unary()
    left = Binary("^", left, right)
  }
  left
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise ParseError {
  let kind = self.peek()
  match kind {
    Op("-") => {
      self.pos = self.pos + 1
      Unary("-", self.parse_unary())
    }
    Op("+") => {
      self.pos = self.pos + 1
      self.parse_unary()
    }
    _ => self.parse_postfix()
  }
}

///|
fn Parser::parse_postfix(self : Parser) -> Expr raise ParseError {
  let mut expr = self.parse_primary()
  while is_op(self.peek(), "%") {
    self.pos = self.pos + 1
    expr = Unary("%", expr)
  }
  expr
}

///|
fn Parser::parse_ref_endpoint(
  self : Parser,
) -> (String, Int, Int) raise ParseError {
  match self.peek() {
    Ref(r, c) => {
      self.pos = self.pos + 1
      ("", r, c)
    }
    Sheet(name) => {
      self.pos = self.pos + 1
      match self.peek() {
        Bang => {
          self.pos = self.pos + 1
          match self.peek() {
            Ref(r, c) => {
              self.pos = self.pos + 1
              (name, r, c)
            }
            _ =>
              raise Unexpected(
                "expected a cell reference after sheet name",
                self.current_pos(),
              )
          }
        }
        _ =>
          raise Unexpected("expected `!` after sheet name", self.current_pos())
      }
    }
    _ => raise Unexpected("expected a cell reference", self.current_pos())
  }
}

///|
fn Parser::finish_ref(
  self : Parser,
  sheet : String,
  r : Int,
  c : Int,
) -> Expr raise ParseError {
  match self.peek() {
    Colon => {
      self.pos = self.pos + 1
      let (sheet2, r2, c2) = self.parse_ref_endpoint()
      let first = sheet
      let second = if sheet2 == "" { first } else { sheet2 }
      if first != "" && sheet2 != "" && first != sheet2 {
        raise Unexpected(
          "3-D references across sheets are not supported",
          self.current_pos(),
        )
      }
      let chosen = if first != "" { first } else { second }
      Range(chosen, r, c, r2, c2)
    }
    _ => Ref(sheet, r, c)
  }
}

///|
fn Parser::parse_call(self : Parser, name : String) -> Expr raise ParseError {
  // Current token is the opening parenthesis.
  self.pos = self.pos + 1
  let args : Array[Expr] = []
  match self.peek() {
    RParen => {
      self.pos = self.pos + 1
      return Call(@value.upper_ascii(name), args)
    }
    _ => ()
  }
  while true {
    args.push(self.parse_expr())
    match self.peek() {
      Comma => self.pos = self.pos + 1
      RParen => {
        self.pos = self.pos + 1
        break
      }
      End => raise UnexpectedEnd(self.current_pos())
      _ =>
        raise Unexpected(
          "expected `,` or `)` in function call",
          self.current_pos(),
        )
    }
  }
  Call(@value.upper_ascii(name), args)
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise ParseError {
  self.depth = self.depth + 1
  if self.depth > 200 {
    raise Unexpected("formula nests too deeply", self.current_pos())
  }
  let kind = self.peek()
  let result = match kind {
    Number(d) => {
      self.pos = self.pos + 1
      Lit(@value.Num(d))
    }
    StringLit(s) => {
      self.pos = self.pos + 1
      Lit(@value.Text(s))
    }
    Ref(r, c) => {
      self.pos = self.pos + 1
      self.finish_ref("", r, c)
    }
    Sheet(name) => {
      self.pos = self.pos + 1
      match self.peek() {
        Bang => {
          self.pos = self.pos + 1
          match self.peek() {
            Ref(r, c) => {
              self.pos = self.pos + 1
              self.finish_ref(name, r, c)
            }
            _ =>
              raise Unexpected(
                "expected a cell reference after sheet name",
                self.current_pos(),
              )
          }
        }
        _ =>
          raise Unexpected("expected `!` after sheet name", self.current_pos())
      }
    }
    Name(n) => {
      self.pos = self.pos + 1
      match self.peek() {
        LParen => self.parse_call(n)
        _ => NameLit(n)
      }
    }
    LParen => {
      self.pos = self.pos + 1
      let inner = self.parse_expr()
      match self.peek() {
        RParen => {
          self.pos = self.pos + 1
          inner
        }
        _ => raise Unexpected("expected `)`", self.current_pos())
      }
    }
    End => raise UnexpectedEnd(self.current_pos())
    _ => raise Unexpected("unexpected token", self.current_pos())
  }
  self.depth = self.depth - 1
  result
}

///|
fn Parser::parse_expr(self : Parser) -> Expr raise ParseError {
  self.parse_comparison()
}

///|
fn parse_impl(text : String) -> Expr raise ParseError {
  let chars = text.code_units()
  let body = if chars.length() > 0 && chars[0].to_int() == 61 {
    text[1:].to_owned()
  } else {
    text
  }
  if @value.trim_ascii(body) == "" {
    raise EmptyFormula
  }
  let toks = match lex(body) {
    Ok(t) => t
    Err(e) => raise e
  }
  let parser : Parser = { toks, pos: 0, depth: 0, }
  let expr = parser.parse_expr()
  if !parser.at_end() {
    raise Unexpected("unexpected trailing input", parser.current_pos())
  }
  expr
}

///|
/// Parse a formula, optionally prefixed with `=`. Returns the expression tree.
pub fn parse(text : String) -> Result[Expr, ParseError] {
  Ok(parse_impl(text)) catch {
    e => Err(e)
  }
}

///|
/// Parse a single cell reference such as `B7` or `$B$7`.
pub fn parse_a1(a1 : String) -> Result[(Int, Int), ParseError] {
  match cell_ref_of(@value.trim_ascii(a1)) {
    Some(rc) => Ok(rc)
    None => Err(Unexpected("invalid cell reference `" + a1 + "`", 0))
  }
}

///|
/// Parse a rectangular area such as `A1:B4` or `Sheet2!A1:B4`. A single cell
/// reference yields a 1x1 area.
pub fn parse_area(text : String) -> Result[Area, ParseError] {
  match parse(text) {
    Ok(Range(sheet, r1, c1, r2, c2)) => Ok({ sheet, r1, c1, r2, c2, })
    Ok(Ref(sheet, r, c)) => Ok({ sheet, r1: r, c1: c, r2: r, c2: c, })
    Ok(_) => Err(Unexpected("not an area reference", 0))
    Err(e) => Err(e)
  }
}

///|
/// Spreadsheet column letters for a 1-based column index: 1 -> A, 27 -> AA.
pub fn column_letters(col : Int) -> String {
  if col < 1 {
    return ""
  }
  let buf : Array[Char] = []
  let mut n = col
  while n > 0 {
    let rem = (n - 1) % 26
    buf.push(Int::unsafe_to_char(65 + rem))
    n = (n - 1) / 26
  }
  let sb = StringBuilder()
  let mut i = buf.length() - 1
  while i >= 0 {
    sb.write_char(buf[i])
    i = i - 1
  }
  sb.to_string()
}

///|
/// A1-style text of a 1-based cell position.
pub fn cell_a1(row : Int, col : Int) -> String {
  column_letters(col) + row.to_string()
}
