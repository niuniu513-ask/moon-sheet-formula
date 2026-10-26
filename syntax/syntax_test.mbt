///|
test "lexer splits numbers strings references and operators" {
  let toks = @syntax.lex("=SUM(A1:B2, $C$3, \"x\"\"y\", 1.5e2)").unwrap()
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
  let toks = @syntax.lex("'My Sheet'!B2<>3").unwrap()
  assert_eq(toks[0].kind, @syntax.Sheet("My Sheet"))
  assert_eq(toks[1].kind, @syntax.Bang)
  assert_eq(toks[2].kind, @syntax.Ref(2, 2))
  assert_eq(toks[3].kind, @syntax.Op("<>"))
  let toks2 = @syntax.lex("A1<=2").unwrap()
  assert_eq(toks2[1].kind, @syntax.Op("<="))
  let toks3 = @syntax.lex("A1>=2").unwrap()
  assert_eq(toks3[1].kind, @syntax.Op(">="))
}

///|
test "lexer rejects malformed input" {
  guard @syntax.lex("\"abc") is Err(@syntax.Unexpected(_, 0)) else {
    abort("expected unterminated string")
  }
  guard @syntax.lex("1e") is Err(@syntax.BadNumber(_, 0)) else {
    abort("expected bad number")
  }
  guard @syntax.lex("A1 # B2") is Err(@syntax.Unexpected(_, 3)) else {
    abort("expected unsupported character")
  }
}

///|
test "parser builds precedence aware trees" {
  let ast = @syntax.parse("1+2*3").unwrap()
  guard ast
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
  let ast2 = @syntax.parse("(1+2)*3").unwrap()
  guard ast2
    is @syntax.Binary(
      "*",
      @syntax.Binary("+", _, _),
      @syntax.Lit(@value.Num(3.0))
    ) else {
    abort("unexpected tree for (1+2)*3")
  }
  // Unary minus binds tighter than power, matching Excel: -2^2 equals 4.
  let ast3 = @syntax.parse("-2^2").unwrap()
  guard ast3
    is @syntax.Binary(
      "^",
      @syntax.Unary("-", @syntax.Lit(@value.Num(2.0))),
      @syntax.Lit(@value.Num(2.0))
    ) else {
    abort("unexpected tree for -2^2")
  }
  let ast4 = @syntax.parse("50%").unwrap()
  guard ast4 is @syntax.Unary("%", @syntax.Lit(@value.Num(50.0))) else {
    abort("unexpected tree for 50%")
  }
  let ast5 = @syntax.parse("1&2&3").unwrap()
  guard ast5
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
  let ast = @syntax.parse("=SUM(Sheet2!A1:B2, Rates)").unwrap()
  guard ast is @syntax.Call("SUM", args) else { abort("expected call") }
  assert_eq(args.length(), 2)
  guard args[0] is @syntax.Range("Sheet2", 1, 1, 2, 2) else {
    abort("expected sheet range")
  }
  guard args[1] is @syntax.NameLit("Rates") else { abort("expected name") }
  let ast2 = @syntax.parse("A1:A3").unwrap()
  guard ast2 is @syntax.Range("", 1, 1, 3, 1) else {
    abort("expected same-sheet range")
  }
  let ast3 = @syntax.parse("IF(A1>0, \"yes\", \"no\")").unwrap()
  guard ast3 is @syntax.Call("IF", _) else { abort("expected IF call") }
}

///|
test "parser reports empty and broken formulas" {
  assert_eq(@syntax.parse("").unwrap_err(), @syntax.ParseError::EmptyFormula)
  assert_eq(@syntax.parse("   ").unwrap_err(), @syntax.ParseError::EmptyFormula)
  guard @syntax.parse("1+") is Err(@syntax.UnexpectedEnd(_)) else {
    abort("expected unexpected end")
  }
  guard @syntax.parse("SUM(1,2") is Err(@syntax.UnexpectedEnd(_)) else {
    abort("expected unexpected end")
  }
  guard @syntax.parse("1 2") is Err(@syntax.Unexpected(_, _)) else {
    abort("expected trailing input error")
  }
  guard @syntax.parse("=") is Err(@syntax.ParseError::EmptyFormula) else {
    abort("expected empty formula")
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
  assert_eq(@syntax.parse_a1("B7").unwrap(), (7, 2))
  assert_eq(@syntax.parse_a1("$B$7").unwrap(), (7, 2))
  guard @syntax.parse_a1("B0") is Err(_) else {
    abort("row zero must be rejected")
  }
  guard @syntax.parse_a1("XFE1") is Err(_) else {
    abort("column beyond XFD must be rejected")
  }
  let area = @syntax.parse_area("A1:C3").unwrap()
  assert_eq(area.size(), 9)
  assert_eq(area.r1, 1)
  assert_eq(area.c2, 3)
  let single = @syntax.parse_area("Sheet3!B2").unwrap()
  assert_eq(single.sheet, "Sheet3")
  assert_eq(single.size(), 1)
}
