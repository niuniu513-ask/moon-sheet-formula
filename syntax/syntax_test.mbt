// The syntax API raises `ParseError`, which keeps the happy path free of
// `Result` plumbing. These four helpers put the result back into data form so
// tests can assert on values and on exact error variants without repeating
// `catch` blocks.

///|
fn lex_result(
  input : String,
) -> Result[Array[@syntax.Token], @syntax.ParseError] {
  Ok(@syntax.lex(input)) catch {
    e => Err(e)
  }
}

///|
fn parse_result(text : String) -> Result[@syntax.Expr, @syntax.ParseError] {
  Ok(@syntax.parse(text)) catch {
    e => Err(e)
  }
}

///|
fn a1_result(a1 : String) -> Result[(Int, Int), @syntax.ParseError] {
  Ok(@syntax.parse_a1(a1)) catch {
    e => Err(e)
  }
}

///|
fn area_result(area : String) -> Result[@syntax.Area, @syntax.ParseError] {
  Ok(@syntax.parse_area(area)) catch {
    e => Err(e)
  }
}

///|
fn lex_ok(input : String) -> Array[@syntax.Token] {
  lex_result(input).unwrap()
}

///|
fn parse_ok(text : String) -> @syntax.Expr {
  parse_result(text).unwrap()
}

///|
fn parse_error(text : String) -> @syntax.ParseError {
  match parse_result(text) {
    Err(e) => e
    Ok(_) => abort("expected a parse error for `" + text + "`")
  }
}

///|
test "lexer splits numbers strings references and operators" {
  let toks = lex_ok("=SUM(A1:B2, $C$3, \"x\"\"y\", 1.5e2)")
  assert_eq(toks.length(), 14)
  assert_eq(toks[0].kind, @syntax.Op("="))
  assert_eq(toks[1].kind, @syntax.Name("SUM"))
  assert_eq(toks[2].kind, @syntax.LParen)
  assert_eq(toks[3].kind, @syntax.Ref(1, 1))
  assert_eq(toks[4].kind, @syntax.Colon)
  assert_eq(toks[5].kind, @syntax.Ref(2, 2))
  assert_eq(toks[6].kind, @syntax.Comma)
  assert_eq(toks[7].kind, @syntax.Ref(3, 3))
  assert_eq(toks[9].kind, @syntax.StringLit("x\"y"))
  assert_eq(toks[11].kind, @syntax.Number(150.0))
  assert_eq(toks[12].kind, @syntax.RParen)
  assert_eq(toks[13].kind, @syntax.End)
}

///|
test "lexer handles quoted sheet names and comparison operators" {
  let toks = lex_ok("'My Sheet'!B2<>3")
  assert_eq(toks[0].kind, @syntax.Sheet("My Sheet"))
  assert_eq(toks[1].kind, @syntax.Bang)
  assert_eq(toks[2].kind, @syntax.Ref(2, 2))
  assert_eq(toks[3].kind, @syntax.Op("<>"))
  assert_eq(lex_ok("A1<=2")[1].kind, @syntax.Op("<="))
  assert_eq(lex_ok("A1>=2")[1].kind, @syntax.Op(">="))
}

///|
test "lexer rejects malformed input" {
  match lex_result("\"abc") {
    Err(@syntax.Unexpected(_, 0)) => ()
    _ => abort("expected unterminated string at offset 0")
  }
  match lex_result("1e") {
    Err(@syntax.BadNumber(_, 0)) => ()
    _ => abort("expected bad number at offset 0")
  }
  match lex_result("A1 # B2") {
    Err(@syntax.Unexpected(_, 3)) => ()
    _ => abort("expected unsupported character at offset 3")
  }
  match lex_result("\"abc") {
    Err(_) => ()
    Ok(_) => abort("quoted text must not lex")
  }
}

///|
test "parser builds precedence aware trees" {
  guard parse_ok("1+2*3")
    is @syntax.Binary(
      "+",
      @syntax.Lit(@value.Num(1.0)),
      @syntax.Binary(
        "*",
        @syntax.Lit(@value.Num(2.0)),
        @syntax.Lit(@value.Num(3.0))
      )
    ) else {
    abort("unexpected tree for 1+2*3")
  }
  guard parse_ok("(1+2)*3")
    is @syntax.Binary(
      "*",
      @syntax.Binary("+", _, _),
      @syntax.Lit(@value.Num(3.0))
    ) else {
    abort("unexpected tree for (1+2)*3")
  }
  // Unary minus binds tighter than power, so -2^2 parses as (-2)^2.
  guard parse_ok("-2^2")
    is @syntax.Binary(
      "^",
      @syntax.Unary("-", @syntax.Lit(@value.Num(2.0))),
      @syntax.Lit(@value.Num(2.0))
    ) else {
    abort("unexpected tree for -2^2")
  }
  guard parse_ok("50%") is @syntax.Unary("%", @syntax.Lit(@value.Num(50.0))) else {
    abort("unexpected tree for 50%")
  }
  guard parse_ok("1&2&3")
    is @syntax.Binary(
      "&",
      @syntax.Binary("&", _, _),
      @syntax.Lit(@value.Num(3.0))
    ) else {
    abort("concatenation should be left associative")
  }
}

///|
test "parser handles references ranges sheets and calls" {
  guard parse_ok("=SUM(Sheet2!A1:B2, Rates)") is @syntax.Call("SUM", args) else {
    abort("expected call")
  }
  assert_eq(args.length(), 2)
  guard args[0] is @syntax.Range("Sheet2", 1, 1, 2, 2) else {
    abort("expected sheet range")
  }
  guard args[1] is @syntax.NameLit("Rates") else { abort("expected name") }
  guard parse_ok("A1:A3") is @syntax.Range("", 1, 1, 3, 1) else {
    abort("expected same-sheet range")
  }
  guard parse_ok("IF(A1>0, \"yes\", \"no\")") is @syntax.Call("IF", _) else {
    abort("expected IF call")
  }
}

///|
test "parser reports empty and broken formulas" {
  assert_eq(parse_error(""), @syntax.ParseError::EmptyFormula)
  assert_eq(parse_error("   "), @syntax.ParseError::EmptyFormula)
  assert_eq(parse_error("="), @syntax.ParseError::EmptyFormula)
  match parse_result("1+") {
    Err(@syntax.UnexpectedEnd(_)) => ()
    _ => abort("expected unexpected end")
  }
  match parse_result("SUM(1,2") {
    Err(@syntax.UnexpectedEnd(_)) => ()
    _ => abort("expected unexpected end for unclosed call")
  }
  match parse_result("1 2") {
    Err(@syntax.Unexpected(_, _)) => ()
    _ => abort("expected trailing input error")
  }
}

///|
test "cell helpers round trip and area parsing works" {
  assert_eq(@syntax.column_letters(1), "A")
  assert_eq(@syntax.column_letters(26), "Z")
  assert_eq(@syntax.column_letters(27), "AA")
  assert_eq(@syntax.column_letters(702), "ZZ")
  assert_eq(@syntax.column_letters(16384), "XFD")
  assert_eq(@syntax.cell_a1(7, 2), "B7")
  assert_eq(a1_result("B7").unwrap(), (7, 2))
  assert_eq(a1_result("$B$7").unwrap(), (7, 2))
  match a1_result("B0") {
    Ok(_) => abort("row zero must be rejected")
    Err(_) => ()
  }
  match a1_result("XFE1") {
    Ok(_) => abort("column beyond XFD must be rejected")
    Err(_) => ()
  }
  let area = area_result("A1:C3").unwrap()
  assert_eq(area.size(), 9)
  assert_eq(area.r1, 1)
  assert_eq(area.c2, 3)
  let single = area_result("Sheet3!B2").unwrap()
  assert_eq(single.sheet, "Sheet3")
  assert_eq(single.size(), 1)
  match area_result("1+1") {
    Ok(_) => abort("a formula is not an area")
    Err(_) => ()
  }
}
