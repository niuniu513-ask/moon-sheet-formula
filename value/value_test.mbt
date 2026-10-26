///|
test "error codes render with spreadsheet text" {
  assert_eq(@value.ErrorCode::DivZero.text(), "#DIV/0!")
  assert_eq(@value.ErrorCode::ValueError.text(), "#VALUE!")
  assert_eq(@value.ErrorCode::Ref.text(), "#REF!")
  assert_eq(@value.ErrorCode::Name.text(), "#NAME?")
  assert_eq(@value.ErrorCode::BadNum.text(), "#NUM!")
  assert_eq(@value.ErrorCode::NA.text(), "#N/A")
  assert_eq(@value.ErrorCode::Null.text(), "#NULL!")
  assert_eq(@value.ErrorCode::Circular.text(), "#CIRCULAR!")
  assert_eq(@value.Err(@value.NA).text(), "#N/A")
}

///|
test "numeric coercion covers blanks booleans and numeric text" {
  assert_eq(@value.Num(2.5).number(), Some(2.5))
  assert_eq(@value.Blank.number(), Some(0.0))
  assert_eq(@value.Bool(true).number(), Some(1.0))
  assert_eq(@value.Bool(false).number(), Some(0.0))
  assert_eq(@value.Text(" 12.5 ").number(), Some(12.5))
  assert_eq(@value.Text("1e3").number(), Some(1000.0))
  assert_eq(@value.Text("50%").number(), Some(0.5))
  assert_eq(@value.Text("-.5").number(), Some(-0.5))
  assert_eq(@value.Text("abc").number(), None)
  assert_eq(@value.Text("").number(), None)
  assert_eq(@value.Text("1,000").number(), None)
  assert_eq(@value.Err(@value.ValueError).number(), None)
  assert_eq(@value.Grid([[@value.Num(1.0)]]).number(), None)
}

///|
test "boolean coercion rejects ambiguous text" {
  assert_eq(@value.Bool(true).boolean(), Some(true))
  assert_eq(@value.Num(0.0).boolean(), Some(false))
  assert_eq(@value.Num(-3.0).boolean(), Some(true))
  assert_eq(@value.Text(" true ").boolean(), Some(true))
  assert_eq(@value.Text("FALSE").boolean(), Some(false))
  assert_eq(@value.Text("yes").boolean(), None)
  assert_eq(@value.Blank.boolean(), Some(false))
  assert_eq(@value.Err(@value.BadNum).boolean(), None)
}

///|
test "text rendering follows spreadsheet conventions" {
  assert_eq(@value.Num(2.0).text(), "2")
  assert_eq(@value.Num(2.5).text(), "2.5")
  assert_eq(@value.Num(-0.0).text(), "0")
  assert_eq(@value.Bool(true).text(), "TRUE")
  assert_eq(@value.Bool(false).text(), "FALSE")
  assert_eq(@value.Blank.text(), "")
  assert_eq(@value.Text("hi").text(), "hi")
  assert_eq(@value.format_number(1234567.0), "1234567")
  assert_eq(@value.format_number(-3.25), "-3.25")
}

///|
test "comparison orders numbers before text before booleans" {
  assert_eq(@value.compare_value(@value.Num(1.0), @value.Num(2.0)), Some(-1))
  assert_eq(@value.compare_value(@value.Num(2.0), @value.Num(2.0)), Some(0))
  assert_eq(@value.compare_value(@value.Num(9.0), @value.Text("a")), Some(-1))
  assert_eq(@value.compare_value(@value.Text("a"), @value.Num(9.0)), Some(1))
  assert_eq(@value.compare_value(@value.Text("A"), @value.Text("a")), Some(0))
  assert_eq(@value.compare_value(@value.Text("a"), @value.Text("b")), Some(-1))
  assert_eq(
    @value.compare_value(@value.Bool(false), @value.Bool(true)),
    Some(-1),
  )
  assert_eq(@value.compare_value(@value.Text("a"), @value.Bool(true)), Some(-1))
  assert_eq(@value.compare_value(@value.Blank, @value.Num(0.0)), Some(0))
  assert_eq(@value.compare_value(@value.Blank, @value.Text("")), Some(0))
  assert_eq(@value.compare_value(@value.Err(@value.NA), @value.Num(1.0)), None)
  assert_eq(
    @value.compare_value(@value.Grid([[@value.Num(1.0)]]), @value.Num(1.0)),
    None,
  )
}

///|
test "flatten and structural equality handle grids" {
  let g : @value.Value = @value.Grid([
    [@value.Num(1.0), @value.Text("a")],
    [@value.Blank, @value.Bool(true)],
  ])
  assert_eq(g.flatten().length(), 4)
  assert_eq(
    @value.Value::same(
      g,
      @value.Grid([
        [@value.Num(1.0), @value.Text("a")],
        [@value.Blank, @value.Bool(true)],
      ]),
    ),
    true,
  )
  assert_eq(@value.Value::same(g, @value.Grid([[@value.Num(1.0)]])), false)
  assert_eq(@value.Value::same(@value.Num(1.0), @value.Num(1.0)), true)
  assert_eq(@value.Value::same(@value.Num(1.0), @value.Text("1")), false)
  assert_eq(g.rows().unwrap().length(), 2)
  guard @value.Num(1.0).rows() is None else { abort("scalars have no rows") }
}
