///|
/// Every implemented function name, uppercase.
let function_names : Array[String] = [
  "ABS", "AND", "AVERAGE", "AVERAGEIF", "AVERAGEIFS", "CEILING", "CHOOSE", "COLUMNS",
  "CONCAT", "CONCATENATE", "COUNT", "COUNTA", "COUNTBLANK", "COUNTIF", "COUNTIFS",
  "DATE", "DAY", "DAYS", "EDATE", "EOMONTH", "EXACT", "EXP", "FALSE", "FIND", "FLOOR",
  "HLOOKUP", "IF", "IFERROR", "IFNA", "IFS", "INDEX", "INT", "ISBLANK", "ISERROR",
  "ISEVEN", "ISLOGICAL", "ISNA", "ISNUMBER", "ISODD", "ISTEXT", "LARGE", "LEFT",
  "LEN", "LN", "LOG", "LOG10", "LOOKUP", "LOWER", "MATCH", "MAX", "MAXIFS", "MEDIAN",
  "MID", "MIN", "MINIFS", "MOD", "MONTH", "N", "NA", "NOT", "OR", "PI", "POWER",
  "PRODUCT", "PROPER", "QUOTIENT", "RANK", "REPT", "RIGHT", "ROUND", "ROUNDDOWN",
  "ROUNDUP", "ROWS", "SEARCH", "SIGN", "SMALL", "SQRT", "SUBSTITUTE", "SUM", "SUMIF",
  "SUMIFS", "SUMPRODUCT", "SWITCH", "TEXT", "TEXTJOIN", "TRIM", "TRUE", "TRUNC",
  "UPPER", "VALUE", "VLOOKUP", "WEEKDAY", "XOR", "YEAR",
]

///|
/// True when the engine must evaluate the arguments itself: these functions
/// skip branches or inspect raw values, so pre-evaluating every argument would
/// change the result.
pub fn is_lazy(name : String) -> Bool {
  match name {
    "IF" | "IFS" | "IFERROR" | "IFNA" | "SWITCH" => true
    _ => false
  }
}

///|
/// True when the function name is part of the library.
pub fn known(name : String) -> Bool {
  for n in function_names {
    if n == name {
      return true
    }
  }
  false
}

///|
/// All function names in alphabetical order.
pub fn names() -> Array[String] {
  function_names.copy()
}

///|
/// Dispatch a non-lazy function call. Returns None for unknown names so the
/// evaluator can report #NAME?.
pub fn call(name : String, args : Array[@value.Value]) -> @value.Value? {
  match name {
    "ABS" => Some(fn_abs(args))
    "AND" => Some(fn_and(args))
    "AVERAGE" => Some(fn_average(args))
    "AVERAGEIF" => Some(fn_averageif(args))
    "AVERAGEIFS" => Some(fn_averageifs(args))
    "CEILING" => Some(fn_ceiling(args))
    "CHOOSE" => Some(fn_choose(args))
    "COLUMNS" => Some(fn_columns(args))
    "CONCAT" => Some(fn_concat(args))
    "CONCATENATE" => Some(fn_concat(args))
    "COUNT" => Some(fn_count(args))
    "COUNTA" => Some(fn_counta(args))
    "COUNTBLANK" => Some(fn_countblank(args))
    "COUNTIF" => Some(fn_countif(args))
    "COUNTIFS" => Some(fn_countifs(args))
    "DATE" => Some(fn_date(args))
    "DAY" => Some(fn_day(args))
    "DAYS" => Some(fn_days(args))
    "EDATE" => Some(fn_edate(args))
    "EOMONTH" => Some(fn_eomonth(args))
    "EXACT" => Some(fn_exact(args))
    "EXP" => Some(fn_exp(args))
    "FALSE" => Some(fn_false(args))
    "FIND" => Some(fn_find(args))
    "FLOOR" => Some(fn_floor(args))
    "HLOOKUP" => Some(fn_hlookup(args))
    "INDEX" => Some(fn_index(args))
    "INT" => Some(fn_int(args))
    "ISBLANK" => Some(fn_isblank(args))
    "ISERROR" => Some(fn_iserror(args))
    "ISEVEN" => Some(fn_iseven(args))
    "ISLOGICAL" => Some(fn_islogical(args))
    "ISNA" => Some(fn_isna(args))
    "ISNUMBER" => Some(fn_isnumber(args))
    "ISODD" => Some(fn_isodd(args))
    "ISTEXT" => Some(fn_istext(args))
    "LARGE" => Some(fn_large(args))
    "LEFT" => Some(fn_left(args))
    "LEN" => Some(fn_len(args))
    "LN" => Some(fn_ln(args))
    "LOG" => Some(fn_log(args))
    "LOG10" => Some(fn_log10(args))
    "LOOKUP" => Some(fn_lookup(args))
    "LOWER" => Some(fn_lower(args))
    "MATCH" => Some(fn_match(args))
    "MAX" => Some(fn_max(args))
    "MAXIFS" => Some(fn_maxifs(args))
    "MEDIAN" => Some(fn_median(args))
    "MID" => Some(fn_mid(args))
    "MIN" => Some(fn_min(args))
    "MINIFS" => Some(fn_minifs(args))
    "MOD" => Some(fn_mod(args))
    "MONTH" => Some(fn_month(args))
    "N" => Some(fn_n(args))
    "NA" => Some(fn_na(args))
    "NOT" => Some(fn_not(args))
    "OR" => Some(fn_or(args))
    "PI" => Some(fn_pi(args))
    "POWER" => Some(fn_power(args))
    "PRODUCT" => Some(fn_product(args))
    "PROPER" => Some(fn_proper(args))
    "QUOTIENT" => Some(fn_quotient(args))
    "RANK" => Some(fn_rank(args))
    "REPT" => Some(fn_rept(args))
    "RIGHT" => Some(fn_right(args))
    "ROUND" => Some(fn_round(args))
    "ROUNDDOWN" => Some(fn_rounddown(args))
    "ROUNDUP" => Some(fn_roundup(args))
    "ROWS" => Some(fn_rows(args))
    "SEARCH" => Some(fn_search(args))
    "SIGN" => Some(fn_sign(args))
    "SMALL" => Some(fn_small(args))
    "SQRT" => Some(fn_sqrt(args))
    "SUBSTITUTE" => Some(fn_substitute(args))
    "SUM" => Some(fn_sum(args))
    "SUMIF" => Some(fn_sumif(args))
    "SUMIFS" => Some(fn_sumifs(args))
    "SUMPRODUCT" => Some(fn_sumproduct(args))
    "TEXT" => Some(fn_text(args))
    "TEXTJOIN" => Some(fn_textjoin(args))
    "TRIM" => Some(fn_trim(args))
    "TRUE" => Some(fn_true(args))
    "TRUNC" => Some(fn_rounddown(args))
    "UPPER" => Some(fn_upper(args))
    "VALUE" => Some(fn_value(args))
    "VLOOKUP" => Some(fn_vlookup(args))
    "WEEKDAY" => Some(fn_weekday(args))
    "XOR" => Some(fn_xor(args))
    "YEAR" => Some(fn_year(args))
    _ => None
  }
}
