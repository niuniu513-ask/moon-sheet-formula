///|
/// The error values a spreadsheet cell can hold. `Circular` is produced by the
/// recalculation engine, not by Excel itself; it marks a formula that takes
/// part in a dependency cycle.
pub(all) enum ErrorCode {
  Null // #NULL!
  DivZero // #DIV/0!
  ValueError // #VALUE!
  Ref // #REF!
  Name // #NAME?
  BadNum // #NUM!
  NA // #N/A
  Circular // #CIRCULAR!
} derive(Eq, Debug)

///|
pub extend ErrorCode with Eq::{equal, not_equal}

///|
pub extend ErrorCode with @debug.Debug::{to_repr}

///|
/// Display text of an error value.
pub fn ErrorCode::text(self : ErrorCode) -> String {
  match self {
    Null => "#NULL!"
    DivZero => "#DIV/0!"
    ValueError => "#VALUE!"
    Ref => "#REF!"
    Name => "#NAME?"
    BadNum => "#NUM!"
    NA => "#N/A"
    Circular => "#CIRCULAR!"
  }
}

///|
/// A spreadsheet cell value. `Grid` only appears while a formula is being
/// evaluated: a range or an argument that spans several cells. Scalars never
/// become grids on their own.
pub(all) enum Value {
  Num(Double)
  Text(String)
  Bool(Bool)
  Blank
  Err(ErrorCode)
  Grid(Array[Array[Value]])
} derive(Eq, Debug)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
/// Display text of a value, following spreadsheet conventions: numbers use the
/// shortest round-trip decimal form, booleans are TRUE/FALSE, blanks are empty.
/// Grids have no textual form and render as an empty string; operators reject
/// them before calling this.
pub fn Value::text(self : Value) -> String {
  match self {
    Num(d) => format_number(d)
    Text(s) => s
    Bool(b) => if b { "TRUE" } else { "FALSE" }
    Blank => ""
    Err(e) => e.text()
    Grid(_) => ""
  }
}

///|
/// Numeric coercion. Blanks become 0, booleans 1/0 and numeric-looking text is
/// parsed. Grids and errors have no numeric value.
pub fn Value::number(self : Value) -> Double? {
  match self {
    Num(d) => Some(d)
    Bool(b) => Some(if b { 1.0 } else { 0.0 })
    Blank => Some(0.0)
    Text(s) => parse_number(s)
    Err(_) => None
    Grid(_) => None
  }
}

///|
/// Boolean coercion: only booleans, numbers (zero is false) and the text forms
/// TRUE/FALSE are accepted.
pub fn Value::boolean(self : Value) -> Bool? {
  match self {
    Bool(b) => Some(b)
    Num(d) => Some(d != 0.0)
    Blank => Some(false)
    Text(s) => {
      let t = trim_ascii(s)
      if t.compare_ignore_ascii_case("TRUE") == 0 {
        Some(true)
      } else if t.compare_ignore_ascii_case("FALSE") == 0 {
        Some(false)
      } else {
        None
      }
    }
    Err(_) | Grid(_) => None
  }
}

///|
/// The error stored in this value, if any.
pub fn Value::error(self : Value) -> ErrorCode? {
  match self {
    Err(e) => Some(e)
    _ => None
  }
}

///|
/// True when the value is an error.
pub fn Value::is_error(self : Value) -> Bool {
  match self {
    Err(_) => true
    _ => false
  }
}

///|
/// Rows of a grid value; scalars have no rows.
pub fn Value::rows(self : Value) -> Array[Array[Value]]? {
  match self {
    Grid(r) => Some(r)
    _ => None
  }
}

///|
/// Row-major scalar cells of an argument: a grid is flattened, a scalar yields
/// a single element.
pub fn Value::flatten(self : Value) -> Array[Value] {
  match self {
    Grid(rs) => {
      let out : Array[Value] = []
      for row in rs {
        for cell in row {
          out.push(cell)
        }
      }
      out
    }
    _ => [self]
  }
}

///|
/// Structural equality used by tests and by SWITCH-style comparison.
pub fn Value::same(self : Value, other : Value) -> Bool {
  match (self, other) {
    (Num(a), Num(b)) => a == b
    (Text(a), Text(b)) => a == b
    (Bool(a), Bool(b)) => a == b
    (Blank, Blank) => true
    (Err(a), Err(b)) => a == b
    (Grid(a), Grid(b)) => {
      if a.length() != b.length() {
        return false
      }
      for i in 0..<a.length() {
        if a[i].length() != b[i].length() {
          return false
        }
        for j in 0..<a[i].length() {
          if !Value::same(a[i][j], b[i][j]) {
            return false
          }
        }
      }
      true
    }
    _ => false
  }
}

///|
/// Spreadsheet ordering used by comparison operators: numbers sort before text,
/// text before booleans, blanks adopt the type of the other side. Text compares
/// case-insensitively. Errors and grids are not comparable.
pub fn compare_value(a : Value, b : Value) -> Int? {
  match (a, b) {
    (Err(_), _) | (_, Err(_)) | (Grid(_), _) | (_, Grid(_)) => None
    (Blank, Blank) => Some(0)
    (Blank, Num(_)) => compare_value(Num(0.0), b)
    (Num(_), Blank) => compare_value(a, Num(0.0))
    (Blank, Bool(_)) => compare_value(Text(""), b)
    (Bool(_), Blank) => compare_value(a, Text(""))
    (Blank, Text(_)) => compare_value(Text(""), b)
    (Text(_), Blank) => compare_value(a, Text(""))
    (Num(x), Num(y)) => Some(if x < y { -1 } else if x > y { 1 } else { 0 })
    (Text(x), Text(y)) => {
      let c = x.compare_ignore_ascii_case(y)
      Some(if c < 0 { -1 } else if c > 0 { 1 } else { 0 })
    }
    (Bool(x), Bool(y)) => Some(if x == y { 0 } else if x { 1 } else { -1 })
    (Num(_), Text(_)) | (Num(_), Bool(_)) => Some(-1)
    (Text(_), Num(_)) => Some(1)
    (Text(_), Bool(_)) => Some(-1)
    (Bool(_), Num(_)) | (Bool(_), Text(_)) => Some(1)
  }
}

///|
/// Wrap a double as a value, turning non-finite results (overflow, NaN) into
/// #NUM! the way a spreadsheet reports unrepresentable arithmetic.
pub fn number_value(d : Double) -> Value {
  if d.is_nan() || d.is_inf() {
    Err(BadNum)
  } else {
    Num(d)
  }
}

///|
/// Shortest round-trip decimal text of a number: integral values print without
/// a fractional part, so 2.0 renders as "2" and 2.5 as "2.5".
pub fn format_number(d : Double) -> String {
  if d == 0.0 {
    return "0"
  }
  if d.is_nan() || d.is_inf() {
    return "#NUM!"
  }
  if d == d.floor() && d.abs() < 1.0e15 {
    return d.to_int64().to_string()
  }
  d.to_string()
}
