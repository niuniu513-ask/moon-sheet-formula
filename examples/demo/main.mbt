// A small end-to-end scenario: build a budget workbook, recalculate it, print a
// few cells, then edit one input and watch an incremental recalculation touch
// only the cells that depend on it.
//
// Run with:  moon run examples/demo --target wasm-gc

///|
fn pad(text : String, width : Int) -> String {
  let mut out = text
  while out.length() < width {
    out = out + " "
  }
  out
}

///|
fn show(label : String, v : @value.Value) -> Unit {
  println("  " + pad(label, 26) + v.text())
}

///|
fn set_all(wb : @calc.Workbook) -> Unit {
  // Sheet "Budget": a tiny purchase order with a formula column.
  let _ = wb.set_text("Budget", "A1", "Item")
  let _ = wb.set_text("Budget", "B1", "Qty")
  let _ = wb.set_text("Budget", "C1", "Unit price")
  let _ = wb.set_text("Budget", "D1", "Line total")
  let _ = wb.set_text("Budget", "A2", "Coffee beans")
  let _ = wb.set_text("Budget", "A3", "Filter paper")
  let _ = wb.set_text("Budget", "A4", "Grinder")
  let _ = wb.set_number("Budget", "B2", 3.0)
  let _ = wb.set_number("Budget", "B3", 10.0)
  let _ = wb.set_number("Budget", "B4", 1.0)
  let _ = wb.set_number("Budget", "C2", 12.5)
  let _ = wb.set_number("Budget", "C3", 1.2)
  let _ = wb.set_number("Budget", "C4", 89.0)
  for row in [2, 3, 4] {
    let _ = wb.set_formula(
      "Budget",
      "D" + row.to_string(),
      "=B" + row.to_string() + "*C" + row.to_string(),
    )
  }
  // Summary block, including a named range, a date calculation and a guard.
  let _ = wb.set_formula("Budget", "B7", "=SUM(D2:D4)")
  let _ = wb.set_formula("Budget", "B8", "=ROUND(AVERAGE(D2:D4), 2)")
  let _ = wb.set_formula("Budget", "B9", "=SUMIF(A2:A4, \"Coffee*\", D2:D4)")
  let _ = wb.set_formula("Budget", "B10", "=ROUND(B7/(1+Tax), 2)")
  let _ = wb.set_formula(
    "Budget", "B11", "=DAYS(DATE(2026,12,31), DATE(2026,1,1))",
  )
  let _ = wb.set_formula("Budget", "B12", "=TEXT(B7, \"#,##0.00\")")
  let _ = wb.set_formula("Budget", "B13", "=IFERROR(B7/0, \"n/a\")")
  // Sheet "Rates" holds the tax rate behind the `Tax` name.
  let _ = wb.set_number("Rates", "B1", 0.13)
  let _ = wb.define_name("Tax", "Rates!B1")
}

///|
fn set_risky(wb : @calc.Workbook) -> Unit {
  let _ = wb.set_formula("Risky", "A1", "=A2")
  let _ = wb.set_formula("Risky", "A2", "=A1+1")
  let _ = wb.set_formula("Risky", "B1", "=Budget!B7*MissingName")
  let _ = wb.set_formula("Risky", "B2", "=1/0")
  let _ = wb.set_formula("Risky", "B3", "=1+")
}

///|
fn main {
  let wb = @calc.Workbook::new()
  set_all(wb)
  let report = wb.recalculate()
  println("=== moon-sheet-formula demo ===")
  println("")
  println("[1] Budget sheet")
  show("Coffee beans line", wb.value_at("Budget", "D2"))
  show("Filter paper line", wb.value_at("Budget", "D3"))
  show("Grinder line", wb.value_at("Budget", "D4"))
  show("Grand total", wb.value_at("Budget", "B7"))
  show("Average line (ROUND 2)", wb.value_at("Budget", "B8"))
  show("Coffee subtotal (SUMIF)", wb.value_at("Budget", "B9"))
  show("Total excl. tax (name)", wb.value_at("Budget", "B10"))
  show("Days in 2026 (DAYS)", wb.value_at("Budget", "B11"))
  show("Formatted total (TEXT)", wb.value_at("Budget", "B12"))
  show("Guarded division", wb.value_at("Budget", "B13"))
  println("")
  println("[2] Evaluation order of the first pass")
  let mut i = 0
  for key in report.order {
    i = i + 1
    println("  " + pad(i.to_string() + ".", 5) + key)
  }
  println(
    "  -> " +
    report.order.length().to_string() +
    " formula cells, " +
    report.diagnostics.length().to_string() +
    " diagnostics",
  )
  println("")
  println("[3] Incremental recalculation after B2 = 12")
  let _ = wb.set_number("Budget", "B2", 12.0)
  let second = wb.recalculate_from(["Budget!B2"])
  println("  recomputed cells: " + second.order.length().to_string())
  let mut j = 0
  for key in second.order {
    j = j + 1
    println("  " + pad(j.to_string() + ".", 5) + key)
  }
  show("New grand total", wb.value_at("Budget", "B7"))
  println("")
  println("[4] Broken cells are reported, not fatal")
  set_risky(wb)
  let third = wb.recalculate()
  show("Risky!A1 (A2 <-> A1)", wb.value_at("Risky", "A1"))
  show("Risky!A2", wb.value_at("Risky", "A2"))
  show("Risky!B1 (unknown name)", wb.value_at("Risky", "B1"))
  show("Risky!B2 (division)", wb.value_at("Risky", "B2"))
  show("Risky!B3 (bad syntax)", wb.value_at("Risky", "B3"))
  show("Budget!B7 still fine", wb.value_at("Budget", "B7"))
  println("  diagnostics:")
  for d in third.diagnostics {
    println("    " + pad(d.cell, 12) + d.message)
  }
  println("")
  println("Done.")
}
