///|
/// A `YYYY-MM-DD` string naming a real calendar date, returned unchanged.
pub fn iso_date() -> Schema[String] {
  {
    json: () => json_object([("type", "string"), ("format", "date")]),
    decode: (input, path) => {
      guard input is String(s) else { fail(path, "expected a string") }
      if !is_calendar_date(s) {
        fail(path, "must be a date in the form YYYY-MM-DD")
      }
      s
    },
  }
}

///|
fn is_calendar_date(text : String) -> Bool {
  let chars = text.to_array()
  guard chars.length() == 10 && chars[4] == '-' && chars[7] == '-' else {
    return false
  }
  let digits = [0, 1, 2, 3, 5, 6, 8, 9]
  guard digits.all(i => chars[i] >= '0' && chars[i] <= '9') else { return false }
  let number = (from : Int, to : Int) => {
    let mut n = 0
    for i = from; i < to; i = i + 1 {
      n = n * 10 + (chars[i].to_int() - '0'.to_int())
    }
    n
  }
  let year = number(0, 4)
  let month = number(5, 7)
  let day = number(8, 10)
  month >= 1 && month <= 12 && day >= 1 && day <= days_in_month(year, month)
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    2 => if is_leap_year(year) { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}
