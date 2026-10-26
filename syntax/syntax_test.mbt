// The syntax API raises `ParseError`, so a test calls it directly when the
// input is valid and uses `try ... catch ... noraise` when it must assert on a
// specific error variant and offset.

///|
test "lexer splits numbers strings references and operators" {
  let toks = @syntax.lex("=SUM(A1:B2, $C$3, \"x\"\"y\", 1.5e2)")
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
  let toks = @syntax.lex("'My Sheet'!B2<>3")
  assert_eq(toks[0].kind, @syntax.Sheet("My Sheet"))
  assert_eq(toks[1].kind, @syntax.Bang)
  assert_eq(toks[2].kind, @syntax.Ref(2, 2))
  assert_eq(toks[3].kind, @syntax.Op("<>"))
  assert_eq(@syntax.lex("A1<=2")[1].kind, @syntax.Op("<="))
  assert_eq(@syntax.lex("A1>=2")[1].kind, @syntax.Op(">="))
}

///|
test "lexer rejects malformed input" {
  try @syntax.lex("\"abc") catch {
    @syntax.Unexpected(_, 0) => ()
    _ => abort("expected unterminated string at offset 0")
  } noraise {
    _ => abort("quoted text must not lex")
  }
  try @syntax.lex("1e") catch {
    @syntax.BadNumber(_, 0) => ()
    _ => abort("expected bad number at offset 0")
  } noraise {
    _ => abort("1e must not lex")
  }
  try @syntax.lex("A1 # B2") catch {
    @syntax.Unexpected(_, 3) => ()
    _ => abort("expected unsupported character at offset 3")
  } noraise {
    _ => abort("# must not lex")
  }
}

///|
test "parser builds precedence aware trees" {
  guard @syntax.parse("1+2*3")
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
  guard @syntax.parse("(1+2)*3")
    is @syntax.Binary(
      "*",
      @syntax.Binary("+", _, _),
      @syntax.Lit(@value.Num(3.0))
    ) else {
    abort("unexpected tree for (1+2)*3")
  }
  // Unary minus binds tighter than power, so -2^2 parses as (-2)^2.
  guard @syntax.parse("-2^2")
    is @syntax.Binary(
      "^",
      @syntax.Unary("-", @syntax.Lit(@value.Num(2.0))),
      @syntax.Lit(@value.Num(2.0))
    ) else {
    abort("unexpected tree for -2^2")
  }
  guard @syntax.parse("50%")
    is @syntax.Unary("%", @syntax.Lit(@value.Num(50.0))) else {
    abort("unexpected tree for 50%")
  }
  guard @syntax.parse("1&2&3")
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
  guard @syntax.parse("=SUM(Sheet2!A1:B2, Rates)") is @syntax.Call("SUM", args) else {
    abort("expected call")
  }
  assert_eq(args.length(), 2)
  guard args[0] is @syntax.Range("Sheet2", 1, 1, 2, 2) else {
    abort("expected sheet range")
  }
  guard args[1] is @syntax.NameLit("Rates") else { abort("expected name") }
  guard @syntax.parse("A1:A3") is @syntax.Range("", 1, 1, 3, 1) else {
    abort("expected same-sheet range")
  }
  guard @syntax.parse("IF(A1>0, \"yes\", \"no\")") is @syntax.Call("IF", _) else {
    abort("expected IF call")
  }
}

///|
test "parser reports empty and broken formulas" {
  try @syntax.parse("") catch {
    @syntax.ParseError::EmptyFormula => ()
    _ => abort("expected an empty formula error")
  } noraise {
    _ => abort("empty formula must fail")
  }
  try @syntax.parse("   ") catch {
    @syntax.ParseError::EmptyFormula => ()
    _ => abort("expected an empty formula error for whitespace")
  } noraise {
    _ => abort("whitespace-only formula must fail")
  }
  try @syntax.parse("=") catch {
    @syntax.ParseError::EmptyFormula => ()
    _ => abort("expected an empty formula error for a bare =")
  } noraise {
    _ => abort("a bare equals sign must fail")
  }
  try @syntax.parse("1+") catch {
    @syntax.UnexpectedEnd(_) => ()
    _ => abort("expected unexpected end")
  } noraise {
    _ => abort("1+ must fail")
  }
  try @syntax.parse("SUM(1,2") catch {
    @syntax.UnexpectedEnd(_) => ()
    _ => abort("expected unexpected end for unclosed call")
  } noraise {
    _ => abort("unclosed call must fail")
  }
  try @syntax.parse("1 2") catch {
    @syntax.Unexpected(_, _) => ()
    _ => abort("expected trailing input error")
  } noraise {
    _ => abort("trailing input must fail")
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
  assert_eq(@syntax.parse_a1("B7"), (7, 2))
  assert_eq(@syntax.parse_a1("$B$7"), (7, 2))
  try @syntax.parse_a1("B0") catch {
    _ => ()
  } noraise {
    _ => abort("row zero must be rejected")
  }
  try @syntax.parse_a1("XFE1") catch {
    _ => ()
  } noraise {
    _ => abort("column beyond XFD must be rejected")
  }
  let area = @syntax.parse_area("A1:C3")
  assert_eq(area.size(), 9)
  assert_eq(area.r1, 1)
  assert_eq(area.c2, 3)
  let single = @syntax.parse_area("Sheet3!B2")
  assert_eq(single.sheet, "Sheet3")
  assert_eq(single.size(), 1)
  try @syntax.parse_area("1+1") catch {
    _ => ()
  } noraise {
    _ => abort("a formula is not an area")
  }
}
