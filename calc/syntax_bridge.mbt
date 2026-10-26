// The syntax package reports failures with MoonBit's error effect, which is the
// right shape for a parser. A recalculation, however, must survive bad input: a
// formula that does not parse becomes a diagnostic for that one cell and the
// rest of the sheet still evaluates. These helpers are the single place where
// the error effect is turned back into ordinary data, so the workbook code does
// not scatter `catch` blocks around.

///|
/// Parse a formula, returning either the tree or the human readable reason.
fn parse_expr_result(text : String) -> Result[@syntax.Expr, String] {
  Ok(@syntax.parse(text)) catch {
    e => Err(parse_error_text(e))
  }
}

///|
/// Parse a cell reference, keeping only "did it work" — every caller turns a
/// failure into its own typed error (`InvalidReference` or `#REF!`).
fn parse_a1_opt(a1 : String) -> (Int, Int)? {
  Some(@syntax.parse_a1(a1)) catch {
    _ => None
  }
}

///|
fn parse_area_opt(text : String) -> @syntax.Area? {
  Some(@syntax.parse_area(text)) catch {
    _ => None
  }
}
