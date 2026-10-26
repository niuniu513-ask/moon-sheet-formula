///|
/// What a cell holds: a constant, nothing, or a formula.
pub(all) enum CellInput {
  Empty
  Number(Double)
  CellText(String)
  Boolean(Bool)
  Formula(String)
} derive(Eq, Debug)

///|
pub extend CellInput with Eq::{equal, not_equal}

///|
pub extend CellInput with @debug.Debug::{to_repr}

///|
/// Workbook-level errors: invalid references, unknown sheets or names, and
/// duplicate named ranges. Cell-level problems are reported as diagnostics in
/// `CalcReport` instead, because one broken cell must not stop a recalculation.
///
/// Plain `enum`, not `suberror`, for the same reason: a rejected write is
/// ordinary data the caller inspects, and nothing here is thrown.
pub(all) enum CalcError {
  InvalidReference(String)
  UnknownSheet(String)
  UnknownName(String)
  DuplicateName(String)
  BadArea(String)
} derive(Eq, Debug)

///|
pub extend CalcError with Eq::{equal, not_equal}

///|
pub extend CalcError with @debug.Debug::{to_repr}

///|
/// One problem found while recalculating, attributed to a `SHEET!A1` cell.
pub(all) struct Diagnostic {
  cell : String
  message : String
} derive(Eq, Debug)

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
/// Result of a recalculation: computed values keyed by `SHEET!A1`, warnings for
/// cells that could not be evaluated, and the evaluation order actually used
/// (useful as an audit trail).
pub(all) struct CalcReport {
  values : Map[String, @value.Value]
  diagnostics : Array[Diagnostic]
  order : Array[String]
} derive(Debug)

///|
pub extend CalcReport with @debug.Debug::{to_repr}

///|
/// A workbook: cells per sheet, named ranges, and the values of the last
/// recalculation. Sheet names are case-sensitive; cell references are not.
pub struct Workbook {
  sheets : Map[String, Map[String, CellInput]]
  names : Map[String, @syntax.Area]
  mut last : Map[String, @value.Value]
}

///|
/// Canonical `SHEET!A1` key for a position.
pub fn cell_key(sheet : String, row : Int, col : Int) -> String {
  sheet + "!" + @syntax.cell_a1(row, col)
}

///|
/// Split a `SHEET!A1` key into its sheet and A1 part.
pub fn split_key(key : String) -> (String, String) {
  match key.find("!") {
    Some(idx) => (key[0:idx].to_owned(), key[idx + 1:].to_owned())
    None => ("", key)
  }
}

///|
pub fn Workbook::new() -> Workbook {
  { sheets: Map([]), names: Map([]), last: Map([]), }
}

///|
fn Workbook::sheet_mut(
  self : Workbook,
  name : String,
) -> Map[String, CellInput] {
  match self.sheets.get(name) {
    Some(m) => m
    None => {
      let m : Map[String, CellInput] = Map([])
      self.sheets[name] = m
      m
    }
  }
}

///|
/// Write any cell input. The A1 text must be a legal cell reference.
pub fn Workbook::set_cell(
  self : Workbook,
  sheet : String,
  a1 : String,
  input : CellInput,
) -> Result[Unit, CalcError] {
  if sheet == "" {
    return Err(InvalidReference(a1))
  }
  match parse_a1_opt(a1) {
    None => Err(InvalidReference(a1))
    Some(rc) => {
      let canonical = @syntax.cell_a1(rc.0, rc.1)
      let cells = self.sheet_mut(sheet)
      if input is Empty {
        let _ = cells.remove(canonical)
      } else {
        cells[canonical] = input
      }
      Ok(())
    }
  }
}

///|
/// Write a numeric constant.
pub fn Workbook::set_number(
  self : Workbook,
  sheet : String,
  a1 : String,
  value : Double,
) -> Result[Unit, CalcError] {
  self.set_cell(sheet, a1, Number(value))
}

///|
/// Write a text constant.
pub fn Workbook::set_text(
  self : Workbook,
  sheet : String,
  a1 : String,
  value : String,
) -> Result[Unit, CalcError] {
  self.set_cell(sheet, a1, CellText(value))
}

///|
/// Write a boolean constant.
pub fn Workbook::set_bool(
  self : Workbook,
  sheet : String,
  a1 : String,
  value : Bool,
) -> Result[Unit, CalcError] {
  self.set_cell(sheet, a1, Boolean(value))
}

///|
/// Write a formula, with or without the leading `=`.
pub fn Workbook::set_formula(
  self : Workbook,
  sheet : String,
  a1 : String,
  formula : String,
) -> Result[Unit, CalcError] {
  self.set_cell(sheet, a1, Formula(formula))
}

///|
/// Remove a cell; an empty cell reads as blank.
pub fn Workbook::clear_cell(
  self : Workbook,
  sheet : String,
  a1 : String,
) -> Result[Unit, CalcError] {
  self.set_cell(sheet, a1, Empty)
}

///|
/// Read a cell back from the workbook model without recalculating. Formulas
/// return their last computed value once `recalculate` has run.
pub fn Workbook::input_at(
  self : Workbook,
  sheet : String,
  a1 : String,
) -> CellInput? {
  match self.sheets.get(sheet) {
    Some(cells) =>
      match parse_a1_opt(a1) {
        Some(rc) =>
          match cells.get(@syntax.cell_a1(rc.0, rc.1)) {
            Some(i) => Some(i)
            None => Some(Empty)
          }
        None => None
      }
    None => None
  }
}

///|
/// Current value of a cell: the last computed value, or the constant itself.
pub fn Workbook::value_at(
  self : Workbook,
  sheet : String,
  a1 : String,
) -> @value.Value {
  match parse_a1_opt(a1) {
    None => @value.Err(@value.Ref)
    Some(rc) => {
      let key = cell_key(sheet, rc.0, rc.1)
      match self.last.get(key) {
        Some(v) => v
        None =>
          match self.sheets.get(sheet) {
            Some(cells) =>
              match cells.get(@syntax.cell_a1(rc.0, rc.1)) {
                Some(Number(d)) => @value.Num(d)
                Some(CellText(t)) => @value.Text(t)
                Some(Boolean(b)) => @value.Bool(b)
                Some(Formula(_)) => @value.Blank
                _ => @value.Blank
              }
            None => @value.Err(@value.Ref)
          }
      }
    }
  }
}

///|
/// Define a named range such as `TaxRate` for `Rates!B2`. Names are stored
/// uppercase so formulas may use any capitalisation.
pub fn Workbook::define_name(
  self : Workbook,
  name : String,
  area_text : String,
) -> Result[Unit, CalcError] {
  let upper = @value.upper_ascii(@value.trim_ascii(name))
  if upper == "" {
    return Err(UnknownName(name))
  }
  match parse_area_opt(area_text) {
    None => Err(BadArea(area_text))
    Some(area) => {
      if self.names.contains(upper) {
        return Err(DuplicateName(upper))
      }
      self.names[upper] = area
      Ok(())
    }
  }
}

///|
/// Defined named ranges, keyed by uppercase name.
pub fn Workbook::named_ranges(self : Workbook) -> Map[String, @syntax.Area] {
  let out : Map[String, @syntax.Area] = Map([])
  for k, v in self.names {
    out[k] = v
  }
  out
}

///|
/// Sheets present in the workbook.
pub fn Workbook::sheet_names(self : Workbook) -> Array[String] {
  let out : Array[String] = []
  for k, _ in self.sheets {
    out.push(k)
  }
  out.sort()
  out
}
