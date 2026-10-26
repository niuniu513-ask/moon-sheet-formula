///|
fn n(d : Double) -> @value.Value {
  @value.Num(d)
}

///|
fn s(t : String) -> @value.Value {
  @value.Text(t)
}

///|
fn grid(rows : Array[Array[@value.Value]]) -> @value.Value {
  @value.Grid(rows)
}

///|
fn call1(name : String, args : Array[@value.Value]) -> @value.Value {
  @functions.call(name, args).unwrap()
}

///|
test "aggregates sum product average min max" {
  assert_eq(call1("SUM", [n(1.0), n(2.0), n(3.0)]), n(6.0))
  assert_eq(call1("SUM", [grid([[n(1.0)], [n(2.0)]])]), n(3.0))
  assert_eq(call1("SUM", [n(1.0), s("ignored"), @value.Blank]), n(1.0))
  assert_eq(call1("PRODUCT", [n(2.0), n(3.0)]), n(6.0))
  assert_eq(call1("AVERAGE", [n(1.0), n(2.0), n(3.0)]), n(2.0))
  assert_eq(call1("AVERAGE", []), @value.Err(@value.DivZero))
  assert_eq(call1("MIN", [n(3.0), n(1.0), n(2.0)]), n(1.0))
  assert_eq(call1("MAX", [n(3.0), n(1.0), n(2.0)]), n(3.0))
  assert_eq(call1("MIN", []), n(0.0))
  assert_eq(
    call1("SUM", [n(1.0), @value.Err(@value.NA)]),
    @value.Err(@value.NA),
  )
}

///|
test "counting distinguishes numbers text and blanks" {
  let range = grid([[n(1.0), s("x")], [@value.Blank, @value.Bool(true)]])
  assert_eq(call1("COUNT", [range]), n(1.0))
  assert_eq(call1("COUNTA", [range]), n(3.0))
  assert_eq(call1("COUNTBLANK", [range]), n(1.0))
  assert_eq(call1("MEDIAN", [n(1.0), n(5.0), n(3.0)]), n(3.0))
  assert_eq(call1("MEDIAN", [n(1.0), n(5.0), n(3.0), n(9.0)]), n(4.0))
  assert_eq(call1("MEDIAN", []), @value.Err(@value.BadNum))
  assert_eq(call1("LARGE", [grid([[n(1.0), n(7.0), n(3.0)]]), n(2.0)]), n(3.0))
  assert_eq(call1("SMALL", [grid([[n(1.0), n(7.0), n(3.0)]]), n(2.0)]), n(3.0))
  assert_eq(call1("LARGE", [n(1.0), n(2.0)]), @value.Err(@value.BadNum))
}

///|
test "criteria functions handle operators and wildcards" {
  let amounts = grid([
    [n(10.0), s("north")],
    [n(20.0), s("North-EAST")],
    [n(5.0), s("south")],
  ])
  let keys = grid([[s("north")], [s("North-EAST")], [s("south")]])
  let values = grid([[n(10.0)], [n(20.0)], [n(5.0)]])
  assert_eq(call1("SUMIF", [keys, s("north"), values]), n(10.0))
  assert_eq(call1("COUNTIF", [keys, s("north")]), n(1.0))
  assert_eq(call1("SUMIF", [values, s(">9")]), n(30.0))
  assert_eq(call1("COUNTIF", [values, s("<>10")]), n(2.0))
  assert_eq(call1("COUNTIF", [keys, s("nor*")]), n(2.0))
  assert_eq(call1("COUNTIF", [keys, s("n?rth")]), n(1.0))
  assert_eq(call1("AVERAGEIF", [values, s(">9")]), n(15.0))
  assert_eq(
    call1("SUMIFS", [values, keys, s("nor*"), values, s(">15")]),
    n(20.0),
  )
  assert_eq(call1("COUNTIFS", [keys, s("nor*"), values, s(">15")]), n(1.0))
  assert_eq(call1("AVERAGEIFS", [values, values, s(">9")]), n(15.0))
  assert_eq(call1("SUMIF", [amounts, s(">9")]), n(30.0))
}

///|
test "rounding family matches spreadsheet rules" {
  assert_eq(call1("ROUND", [n(2.5)]), n(3.0))
  assert_eq(call1("ROUND", [n(-2.5)]), n(-3.0))
  assert_eq(call1("ROUND", [n(1.2345), n(2.0)]), n(1.23))
  assert_eq(call1("ROUND", [n(1234.0), n(-2.0)]), n(1200.0))
  assert_eq(call1("ROUNDUP", [n(1.21), n(1.0)]), n(1.3))
  assert_eq(call1("ROUNDUP", [n(-1.21), n(1.0)]), n(-1.3))
  assert_eq(call1("ROUNDDOWN", [n(1.29), n(1.0)]), n(1.2))
  assert_eq(call1("TRUNC", [n(-1.29)]), n(-1.0))
  assert_eq(call1("MOD", [n(5.0), n(3.0)]), n(2.0))
  assert_eq(call1("MOD", [n(-5.0), n(3.0)]), n(1.0))
  assert_eq(call1("MOD", [n(5.0), n(0.0)]), @value.Err(@value.DivZero))
  assert_eq(call1("QUOTIENT", [n(7.0), n(2.0)]), n(3.0))
  assert_eq(call1("INT", [n(-1.5)]), n(-2.0))
  assert_eq(call1("CEILING", [n(2.1), n(0.5)]), n(2.5))
  assert_eq(call1("CEILING", [n(-2.1), n(-0.5)]), n(-2.5))
  assert_eq(call1("CEILING", [n(2.1), n(-0.5)]), @value.Err(@value.BadNum))
  assert_eq(call1("FLOOR", [n(2.9), n(0.5)]), n(2.5))
  assert_eq(call1("SQRT", [n(9.0)]), n(3.0))
  assert_eq(call1("SQRT", [n(-1.0)]), @value.Err(@value.BadNum))
  assert_eq(call1("POWER", [n(2.0), n(10.0)]), n(1024.0))
  assert_eq(call1("ABS", [n(-3.0)]), n(3.0))
  assert_eq(call1("SIGN", [n(-3.0)]), n(-1.0))
  assert_eq(
    call1("SUMPRODUCT", [grid([[n(1.0), n(2.0)]]), grid([[n(3.0), n(4.0)]])]),
    n(11.0),
  )
}

///|
test "text functions cover slicing joining and search" {
  assert_eq(call1("LEN", [s("hello")]), n(5.0))
  assert_eq(call1("LEN", [n(12.5)]), n(4.0))
  assert_eq(call1("LEFT", [s("hello"), n(2.0)]), s("he"))
  assert_eq(call1("RIGHT", [s("hello"), n(2.0)]), s("lo"))
  assert_eq(call1("RIGHT", [s("hi")]), s("i"))
  assert_eq(call1("MID", [s("hello"), n(2.0), n(3.0)]), s("ell"))
  assert_eq(call1("MID", [s("hello"), n(9.0), n(2.0)]), s(""))
  assert_eq(call1("TRIM", [s("  a   b  ")]), s("a b"))
  assert_eq(call1("UPPER", [s("aBc")]), s("ABC"))
  assert_eq(call1("LOWER", [s("aBc")]), s("abc"))
  assert_eq(call1("CONCAT", [s("a"), n(1.0), @value.Bool(true)]), s("a1TRUE"))
  assert_eq(
    call1("TEXTJOIN", [s("-"), @value.Bool(true), s("a"), s(""), s("b")]),
    s("a-b"),
  )
  assert_eq(call1("FIND", [s("l"), s("hello")]), n(3.0))
  assert_eq(call1("FIND", [s("L"), s("hello")]), @value.Err(@value.ValueError))
  assert_eq(call1("SEARCH", [s("L"), s("hello")]), n(3.0))
  assert_eq(call1("FIND", [s("l"), s("hello"), n(4.0)]), n(4.0))
  assert_eq(call1("SUBSTITUTE", [s("a-b-c"), s("-"), s("+")]), s("a+b+c"))
  assert_eq(
    call1("SUBSTITUTE", [s("a-b-c"), s("-"), s("+"), n(2.0)]),
    s("a-b+c"),
  )
  assert_eq(call1("REPT", [s("ab"), n(3.0)]), s("ababab"))
  assert_eq(call1("REPT", [s("ab"), n(-1.0)]), @value.Err(@value.ValueError))
  assert_eq(call1("VALUE", [s("12.5%")]), n(0.125))
  assert_eq(call1("VALUE", [s("abc")]), @value.Err(@value.ValueError))
  assert_eq(call1("TEXT", [n(1234.5), s("#,##0.00")]), s("1,234.50"))
  assert_eq(call1("TEXT", [n(0.256), s("0.0%")]), s("25.6%"))
  assert_eq(call1("TEXT", [n(7.0), s("000")]), s("7"))
  assert_eq(call1("EXACT", [s("a"), s("A")]), @value.Bool(false))
}

///|
test "lookup functions resolve rows columns and matches" {
  let table = grid([
    [s("A"), n(10.0), s("first")],
    [s("B"), n(20.0), s("second")],
    [s("C"), n(30.0), s("third")],
  ])
  assert_eq(
    call1("VLOOKUP", [s("B"), table, n(2.0), @value.Bool(false)]),
    n(20.0),
  )
  assert_eq(
    call1("VLOOKUP", [s("B"), table, n(3.0), @value.Bool(false)]),
    s("second"),
  )
  assert_eq(
    call1("VLOOKUP", [s("Z"), table, n(2.0), @value.Bool(false)]),
    @value.Err(@value.NA),
  )
  // Approximate lookup picks the largest key not greater than the probe.
  assert_eq(call1("VLOOKUP", [s("Z"), table, n(2.0)]), n(30.0))
  assert_eq(call1("VLOOKUP", [s("B"), table, n(9.0)]), @value.Err(@value.Ref))
  let by_score = grid([
    [n(10.0), s("low")],
    [n(20.0), s("mid")],
    [n(30.0), s("high")],
  ])
  assert_eq(call1("VLOOKUP", [n(25.0), by_score, n(2.0)]), s("mid"))
  assert_eq(
    call1("HLOOKUP", [
      n(20.0),
      grid([[n(10.0), n(20.0)], [s("a"), s("b")]]),
      n(2.0),
      @value.Bool(false),
    ]),
    s("b"),
  )
  assert_eq(call1("INDEX", [table, n(2.0), n(3.0)]), s("second"))
  assert_eq(call1("INDEX", [table, n(9.0), n(1.0)]), @value.Err(@value.Ref))
  assert_eq(call1("INDEX", [grid([[n(1.0), n(2.0), n(3.0)]]), n(2.0)]), n(2.0))
  assert_eq(
    call1("MATCH", [s("B"), grid([[s("A")], [s("B")], [s("C")]]), n(0.0)]),
    n(2.0),
  )
  assert_eq(
    call1("MATCH", [n(25.0), grid([[n(10.0)], [n(20.0)], [n(30.0)]])]),
    n(2.0),
  )
  assert_eq(
    call1("MATCH", [s("Z"), grid([[s("A")], [s("B")]]), n(0.0)]),
    @value.Err(@value.NA),
  )
  assert_eq(call1("CHOOSE", [n(2.0), s("a"), s("b"), s("c")]), s("b"))
  assert_eq(call1("CHOOSE", [n(9.0), s("a")]), @value.Err(@value.ValueError))
  assert_eq(call1("ROWS", [table]), n(3.0))
  assert_eq(call1("COLUMNS", [table]), n(3.0))
}

///|
test "date functions use the 1899-12-30 serial system" {
  assert_eq(call1("DATE", [n(2024.0), n(1.0), n(1.0)]), n(45292.0))
  assert_eq(call1("DATE", [n(2024.0), n(13.0), n(1.0)]), n(45658.0))
  assert_eq(call1("YEAR", [n(45292.0)]), n(2024.0))
  assert_eq(call1("MONTH", [n(45292.0)]), n(1.0))
  assert_eq(call1("DAY", [n(45292.0)]), n(1.0))
  assert_eq(call1("DAYS", [n(45292.0), n(45261.0)]), n(31.0))
  // 2024 is a leap year: EDATE clamps 31 January + 1 month to 29 February.
  let jan31 = call1("DATE", [n(2024.0), n(1.0), n(31.0)])
  let feb29 = call1("DATE", [n(2024.0), n(2.0), n(29.0)])
  assert_eq(call1("EDATE", [jan31, n(1.0)]), feb29)
  assert_eq(
    call1("DATE", [n(2024.0), n(2.0), n(30.0)]),
    call1("DATE", [n(2024.0), n(3.0), n(1.0)]),
  )
  assert_eq(call1("YEAR", [n(0.0)]), n(1899.0))
  assert_eq(
    call1("DATE", [n(1800.0), n(1.0), n(1.0)]),
    @value.Err(@value.BadNum),
  )
}

///|
test "information and logical helpers" {
  assert_eq(call1("ISBLANK", [@value.Blank]), @value.Bool(true))
  assert_eq(call1("ISBLANK", [s("")]), @value.Bool(false))
  assert_eq(call1("ISNUMBER", [n(1.0)]), @value.Bool(true))
  assert_eq(call1("ISTEXT", [s("x")]), @value.Bool(true))
  assert_eq(call1("ISLOGICAL", [@value.Bool(true)]), @value.Bool(true))
  assert_eq(call1("ISERROR", [@value.Err(@value.NA)]), @value.Bool(true))
  assert_eq(call1("ISNA", [@value.Err(@value.NA)]), @value.Bool(true))
  assert_eq(call1("ISNA", [@value.Err(@value.Ref)]), @value.Bool(false))
  assert_eq(call1("NA", []), @value.Err(@value.NA))
  assert_eq(call1("N", [s("abc")]), n(0.0))
  assert_eq(call1("N", [@value.Bool(true)]), n(1.0))
  assert_eq(call1("NOT", [@value.Bool(true)]), @value.Bool(false))
  assert_eq(call1("NOT", [n(0.0)]), @value.Bool(true))
  assert_eq(call1("TRUE", []), @value.Bool(true))
  assert_eq(
    call1("XOR", [@value.Bool(true), @value.Bool(false)]),
    @value.Bool(true),
  )
  assert_eq(
    call1("XOR", [@value.Bool(true), @value.Bool(true)]),
    @value.Bool(false),
  )
}

///|
test "unknown functions and lazy names are reported honestly" {
  assert_eq(@functions.call("NOPE", []), None)
  assert_eq(@functions.known("NOPE"), false)
  assert_eq(@functions.known("IF"), true)
  assert_eq(@functions.is_lazy("IF"), true)
  assert_eq(@functions.is_lazy("SUM"), false)
  assert_eq(@functions.names().length() >= 80, true)
}

///|
test "conditional extremes pick the best matching row" {
  let values = grid([[n(10.0)], [n(20.0)], [n(5.0)]])
  let regions = grid([[s("north")], [s("North-East")], [s("south")]])
  assert_eq(call1("MAXIFS", [values, regions, s("north*")]), n(20.0))
  assert_eq(call1("MINIFS", [values, regions, s("north*")]), n(10.0))
  assert_eq(call1("MAXIFS", [values, regions, s("west")]), n(0.0))
  assert_eq(
    call1("MAXIFS", [values, grid([[s("x")]]), s("north*")]),
    @value.Err(@value.ValueError),
  )
}

///|
test "rank and lookup walk sorted data" {
  let pool = grid([[n(10.0), n(20.0), n(30.0)]])
  assert_eq(call1("RANK", [n(10.0), pool]), n(3.0))
  assert_eq(call1("RANK", [n(10.0), pool, n(1.0)]), n(1.0))
  assert_eq(call1("RANK", [n(99.0), pool]), @value.Err(@value.NA))
  let keys = grid([[n(10.0), n(20.0), n(30.0)]])
  let labels = grid([[s("a"), s("b"), s("c")]])
  assert_eq(call1("LOOKUP", [n(25.0), keys, labels]), s("b"))
  assert_eq(call1("LOOKUP", [n(20.0), keys, labels]), s("b"))
  assert_eq(call1("LOOKUP", [n(20.0), keys]), n(20.0))
  assert_eq(call1("LOOKUP", [n(5.0), keys]), @value.Err(@value.NA))
  assert_eq(
    call1("LOOKUP", [n(25.0), keys, grid([[s("a")]])]),
    @value.Err(@value.Ref),
  )
}

///|
test "weekday and month end follow calendar rules" {
  // 1970-01-01 was a Thursday.
  assert_eq(call1("WEEKDAY", [n(25569.0)]), n(5.0))
  assert_eq(call1("WEEKDAY", [n(25569.0), n(2.0)]), n(4.0))
  assert_eq(call1("WEEKDAY", [n(25569.0), n(3.0)]), n(3.0))
  assert_eq(call1("WEEKDAY", [n(25569.0), n(9.0)]), @value.Err(@value.BadNum))
  let jan15 = call1("DATE", [n(2026.0), n(1.0), n(15.0)])
  let jan31 = call1("DATE", [n(2026.0), n(1.0), n(31.0)])
  assert_eq(call1("EOMONTH", [jan15, n(0.0)]), jan31)
  let leap = call1("DATE", [n(2024.0), n(1.0), n(31.0)])
  let feb29 = call1("DATE", [n(2024.0), n(2.0), n(29.0)])
  assert_eq(call1("EOMONTH", [leap, n(1.0)]), feb29)
}

///|
test "logical group functions accept booleans and numbers" {
  assert_eq(call1("AND", [@value.Bool(true), n(1.0)]), @value.Bool(true))
  assert_eq(call1("AND", [@value.Bool(true), n(0.0)]), @value.Bool(false))
  assert_eq(call1("AND", []), @value.Err(@value.ValueError))
  assert_eq(call1("OR", [@value.Bool(false), n(1.0)]), @value.Bool(true))
  assert_eq(
    call1("OR", [@value.Bool(false), @value.Bool(false)]),
    @value.Bool(false),
  )
  assert_eq(call1("XOR", [n(1.0), n(0.0), n(1.0)]), @value.Bool(false))
  assert_eq(call1("ISEVEN", [n(4.0)]), @value.Bool(true))
  assert_eq(call1("ISODD", [n(4.0)]), @value.Bool(false))
  assert_eq(call1("ISODD", [n(-3.0)]), @value.Bool(true))
}

///|
test "proper case formatting" {
  assert_eq(call1("PROPER", [s("hello WORLD")]), s("Hello World"))
  assert_eq(call1("PROPER", [s("o'neil 2nd")]), s("O'Neil 2nd"))
}
