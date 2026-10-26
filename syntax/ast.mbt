///|
/// A syntax error with the character offset where it was detected.
///
/// This is a `suberror`, so the public API reports failures with MoonBit's
/// error effect (`Array[Token] raise ParseError`). The recalculation layer
/// catches it immediately and turns it into a cell-level diagnostic, so a bad
/// formula never aborts the whole pass.
pub(all) suberror ParseError {
  Unexpected(String, Int)
  UnexpectedEnd(Int)
  BadNumber(String, Int)
  EmptyFormula
} derive(Eq, Debug)

///|
pub extend ParseError with Eq::{equal, not_equal}

///|
pub extend ParseError with @debug.Debug::{to_repr}

///|
/// Parsed formula tree. Cell positions are 1-based rows and columns; the sheet
/// string is empty when the formula refers to its own sheet.
pub enum Expr {
  Lit(@value.Value)
  Ref(String, Int, Int)
  Range(String, Int, Int, Int, Int)
  NameLit(String)
  Call(String, Array[Expr])
  Unary(String, Expr)
  Binary(String, Expr, Expr)
} derive(Debug)

///|
pub extend Expr with @debug.Debug::{to_repr}

///|
/// A range reference resolved to absolute coordinates.
pub(all) struct Area {
  sheet : String
  r1 : Int
  c1 : Int
  r2 : Int
  c2 : Int
} derive(Eq, Debug)

///|
pub extend Area with Eq::{equal, not_equal}

///|
pub extend Area with @debug.Debug::{to_repr}

///|
/// Number of cells an area covers.
pub fn Area::size(self : Area) -> Int {
  (self.r2 - self.r1 + 1) * (self.c2 - self.c1 + 1)
}
