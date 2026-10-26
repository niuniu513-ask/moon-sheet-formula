///|
fn diag_for(report : @calc.CalcReport, key : String) -> String? {
  for d in report.diagnostics {
    if d.cell == key {
      return Some(d.message)
    }
  }
  None
}

///|
fn has_key(order : Array[String], key : String) -> Bool {
  let mut found = false
  for k in order {
    if k == key {
      found = true
    }
  }
  found
}

///|
test "workbook stores constants and evaluates formulas" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 2.0)
  let _ = wb.set_number("S", "A2", 3.0)
  let _ = wb.set_formula("S", "A3", "=A1*A2")
  let _ = wb.set_formula("S", "A4", "=SUM(A1:A2)")
  assert_eq(wb.value_at("S", "A3"), @value.Blank)
  let report = wb.recalculate()
  assert_eq(report.diagnostics.length(), 0)
  assert_eq(report.order.length(), 2)
  assert_eq(wb.value_at("S", "A3"), @value.Num(6.0))
  assert_eq(wb.value_at("S", "A4"), @value.Num(5.0))
  assert_eq(report.values.get("S!A3"), Some(@value.Num(6.0)))
}

///|
test "cells accept canonical and absolute references" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "$A$1", 7.0)
  assert_eq(wb.input_at("S", "a1"), Some(@calc.Number(7.0)))
  guard wb.set_cell("S", "not-a-ref", @calc.Number(1.0))
    is Err(@calc.InvalidReference(_)) else {
    abort("expected InvalidReference")
  }
  guard wb.set_cell("", "A1", @calc.Number(1.0))
    is Err(@calc.InvalidReference(_)) else {
    abort("expected InvalidReference for empty sheet name")
  }
  let _ = wb.clear_cell("S", "A1")
  assert_eq(wb.value_at("S", "A1"), @value.Blank)
}

///|
test "recalculation follows dependency order" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 1.0)
  let _ = wb.set_formula("S", "B1", "=A1+1")
  let _ = wb.set_formula("S", "C1", "=A1+2")
  let _ = wb.set_formula("S", "D1", "=B1*C1")
  let report = wb.recalculate()
  assert_eq(report.order, ["S!B1", "S!C1", "S!D1"])
  assert_eq(wb.value_at("S", "D1"), @value.Num(6.0))
}

///|
test "long chains evaluate in one pass" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 1.0)
  let _ = wb.set_formula("S", "A2", "=A1*2")
  let _ = wb.set_formula("S", "A3", "=A2*2")
  let _ = wb.set_formula("S", "A4", "=A3*2")
  let report = wb.recalculate()
  assert_eq(report.order, ["S!A2", "S!A3", "S!A4"])
  assert_eq(wb.value_at("S", "A4"), @value.Num(8.0))
}

///|
test "cycles are detected and reported per cell" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_formula("S", "A1", "=B1")
  let _ = wb.set_formula("S", "B1", "=A1")
  let _ = wb.set_formula("S", "C1", "=C1+1")
  let _ = wb.set_formula("S", "D1", "=5")
  let report = wb.recalculate()
  assert_eq(wb.value_at("S", "A1"), @value.Err(@value.Circular))
  assert_eq(wb.value_at("S", "B1"), @value.Err(@value.Circular))
  assert_eq(wb.value_at("S", "C1"), @value.Err(@value.Circular))
  assert_eq(wb.value_at("S", "D1"), @value.Num(5.0))
  assert_eq(report.diagnostics.length(), 3)
  assert_eq(diag_for(report, "S!A1"), Some("circular reference"))
  assert_eq(diag_for(report, "S!C1"), Some("circular reference"))
}

///|
test "incremental recalculation only touches the affected closure" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 1.0)
  let _ = wb.set_formula("S", "B1", "=A1*2")
  let _ = wb.set_formula("S", "C1", "=B1+1")
  let _ = wb.set_number("S", "D1", 10.0)
  let _ = wb.set_formula("S", "E1", "=D1*3")
  let first = wb.recalculate()
  assert_eq(first.order.length(), 3)
  assert_eq(wb.value_at("S", "E1"), @value.Num(30.0))
  let _ = wb.set_number("S", "A1", 5.0)
  let second = wb.recalculate_from(["S!A1"])
  assert_eq(second.order.length(), 2)
  assert_true(has_key(second.order, "S!B1"))
  assert_true(has_key(second.order, "S!C1"))
  assert_eq(wb.value_at("S", "C1"), @value.Num(11.0))
  // E1 is outside the closure: its cached value survives untouched.
  assert_eq(second.values.get("S!E1"), Some(@value.Num(30.0)))
  assert_eq(second.order.length() + 0, 2)
}

///|
test "editing a leaf constant invalidates every reader" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 2.0)
  let _ = wb.set_formula("S", "B1", "=A1*10")
  let _ = wb.recalculate()
  let _ = wb.set_number("S", "A1", 4.0)
  let report = wb.recalculate_from(["S!A1"])
  assert_eq(report.order, ["S!B1"])
  assert_eq(wb.value_at("S", "B1"), @value.Num(40.0))
}

///|
test "named ranges resolve to scalars and rectangles" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "D1", 0.05)
  let _ = wb.set_number("S", "A1", 200.0)
  let _ = wb.set_number("S", "B1", 1.0)
  let _ = wb.set_number("S", "B2", 2.0)
  let _ = wb.set_number("S", "B3", 3.0)
  let _ = wb.set_formula("S", "A2", "=A1*rate")
  let _ = wb.set_formula("S", "A3", "=SUM(Numbers)")
  guard wb.define_name("rate", "S!D1") is Ok(_) else {
    abort("define_name failed")
  }
  guard wb.define_name("Numbers", "S!B1:B3") is Ok(_) else {
    abort("define_name failed")
  }
  guard wb.define_name("RATE", "S!D1") is Err(@calc.DuplicateName(_)) else {
    abort("expected DuplicateName")
  }
  guard wb.define_name("Bad", "1+1") is Err(@calc.BadArea(_)) else {
    abort("expected BadArea")
  }
  let report = wb.recalculate()
  assert_eq(report.diagnostics.length(), 0)
  assert_eq(wb.value_at("S", "A2"), @value.Num(10.0))
  assert_eq(wb.value_at("S", "A3"), @value.Num(6.0))
  assert_eq(wb.named_ranges().length(), 2)
}

///|
test "cross sheet references and missing sheets" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("Data", "A1", 10.0)
  let _ = wb.set_number("Data", "A2", 20.0)
  let _ = wb.set_number("Data", "A3", 30.0)
  let _ = wb.set_formula("Report", "B2", "=SUM(Data!A1:A3)")
  let _ = wb.set_formula("Report", "B3", "='Data'!A1+'Data'!A2")
  let _ = wb.set_formula("Report", "B4", "=SUM(Ghost!A1:A2)")
  let report = wb.recalculate()
  assert_eq(wb.value_at("Report", "B2"), @value.Num(60.0))
  assert_eq(wb.value_at("Report", "B3"), @value.Num(30.0))
  assert_eq(wb.value_at("Report", "B4"), @value.Err(@value.Ref))
  assert_eq(wb.sheet_names(), ["Data", "Report"])
  assert_eq(report.order.length(), 3)
}

///|
test "errors propagate upward and stay attributed to their cell" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_formula("S", "A1", "=1/0")
  let _ = wb.set_formula("S", "A2", "=A1+1")
  let _ = wb.set_formula("S", "B1", "=NOPE(1)")
  let _ = wb.set_formula("S", "B2", "=1+")
  let _ = wb.set_formula("S", "C1", "=1+\"x\"")
  let _ = wb.set_formula("S", "C2", "=A1")
  let report = wb.recalculate()
  assert_eq(wb.value_at("S", "A1"), @value.Err(@value.DivZero))
  assert_eq(wb.value_at("S", "A2"), @value.Err(@value.DivZero))
  assert_eq(wb.value_at("S", "B1"), @value.Err(@value.Name))
  assert_eq(wb.value_at("S", "B2"), @value.Err(@value.ValueError))
  assert_eq(wb.value_at("S", "C1"), @value.Err(@value.ValueError))
  assert_eq(wb.value_at("S", "C2"), @value.Err(@value.DivZero))
  assert_eq(report.diagnostics.length(), 1)
  match diag_for(report, "S!B2") {
    Some(msg) =>
      match msg.find("parse") {
        Some(_) => ()
        None => abort("expected parse diagnostic, got " + msg)
      }
    None => abort("expected a diagnostic for S!B2")
  }
}

///|
test "lazy functions skip branches that would fail" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 4.0)
  let _ = wb.set_formula("S", "B1", "=IF(A1>0, A1*2, 1/0)")
  let _ = wb.set_formula("S", "B2", "=IF(A1<0, 1/0, A1+1)")
  let _ = wb.set_formula("S", "B3", "=IFERROR(1/0, 42)")
  let _ = wb.set_formula("S", "B4", "=IFNA(NA(), 7)")
  let _ = wb.set_formula(
    "S", "B5", "=SWITCH(A1, 1, \"one\", 4, \"four\", \"other\")",
  )
  let _ = wb.set_formula("S", "B6", "=IFS(A1<0, \"neg\", A1>0, \"pos\")")
  let report = wb.recalculate()
  assert_eq(report.diagnostics.length(), 0)
  assert_eq(wb.value_at("S", "B1"), @value.Num(8.0))
  assert_eq(wb.value_at("S", "B2"), @value.Num(5.0))
  assert_eq(wb.value_at("S", "B3"), @value.Num(42.0))
  assert_eq(wb.value_at("S", "B4"), @value.Num(7.0))
  assert_eq(wb.value_at("S", "B5"), @value.Text("four"))
  assert_eq(wb.value_at("S", "B6"), @value.Text("pos"))
}

///|
test "blank references count as zero and dependencies are listed" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 1.0)
  let _ = wb.set_formula("S", "B1", "=SUM(A1:A3)+D1")
  let _ = wb.recalculate()
  assert_eq(wb.value_at("S", "B1"), @value.Num(1.0))
  assert_eq(wb.dependencies("S", "B1"), ["S!A1", "S!A2", "S!A3", "S!D1"])
  assert_eq(wb.dependencies("S", "A1").length(), 0)
}

///|
test "standalone formulas evaluate against the last result" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 3.0)
  let _ = wb.set_number("S", "A2", 4.0)
  let _ = wb.set_formula("S", "A3", "=A1^2")
  let _ = wb.recalculate()
  assert_eq(wb.evaluate_formula("S", "=A1+A2"), @value.Num(7.0))
  assert_eq(wb.evaluate_formula("S", "=A3/2"), @value.Num(4.5))
  assert_eq(wb.evaluate_formula("S", "=1+"), @value.Err(@value.ValueError))
  assert_eq(wb.evaluate_formula("S", "=CONCAT(\"a\", A1)"), @value.Text("a3"))
  assert_eq(wb.evaluate_formula("Other", "=A1"), @value.Err(@value.Ref))
}

///|
test "oversized ranges are rejected instead of expanding" {
  let wb = @calc.Workbook::new()
  let _ = wb.set_number("S", "A1", 1.0)
  let _ = wb.set_formula("S", "B1", "=SUM(A1:Z2000)")
  let report = wb.recalculate()
  assert_eq(wb.value_at("S", "B1"), @value.Err(@value.Name))
  match diag_for(report, "S!B1") {
    Some(msg) =>
      match msg.find("larger than") {
        Some(_) => ()
        None => abort("expected range size diagnostic, got " + msg)
      }
    None => abort("expected a diagnostic for S!B1")
  }
}
