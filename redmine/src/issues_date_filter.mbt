///|
/// A named span of time understood by every Redmine date filter.
pub(all) enum DatePeriod {
  Today
  Yesterday
  ThisWeek
  LastWeek
  LastTwoWeeks
  ThisMonth
  LastMonth
  ThisYear
  /// Matches issues that have a value in the field.
  Any
  /// Matches issues that have no value in the field.
  Blank
} derive(Eq, Debug)

///|
pub extend DatePeriod with Eq::{equal, not_equal}

///|
pub extend DatePeriod with @debug.Debug::{to_repr}

///|
/// A filter for the issue fields Redmine types as `:date_past` (`created_on`,
/// `updated_on`, `closed_on`), which answer 422 to any forward-looking filter.
/// Dates are `YYYY-MM-DD`; day counts are zero or more.
pub(all) enum PastDateFilter {
  /// That day.
  On(String)
  Period(DatePeriod)
  /// On or after `from` and on or before `to`.
  Between(from~ : String, to~ : String)
  /// On or after the day.
  Since(String)
  /// On or before the day.
  Until(String)
  /// The single day that many days ago.
  DaysAgo(Int32)
  /// On or after the day that many days ago.
  SinceDaysAgo(Int32)
  /// From the day that many days ago through today.
  LastDays(Int32)
  /// On or before the day that many days ago.
  UntilDaysAgo(Int32)
} derive(Eq, Debug)

///|
pub extend PastDateFilter with Eq::{equal, not_equal}

///|
pub extend PastDateFilter with @debug.Debug::{to_repr}

///|
/// A filter for the issue fields Redmine types as `:date` (`start_date`,
/// `due_date`): every past-looking form plus the forward-looking ones.
pub(all) enum DateFilter {
  Past(PastDateFilter)
  Tomorrow
  NextWeek
  NextMonth
  /// The single day that many days from now.
  DaysFromNow(Int32)
  /// On or after the day that many days from now.
  SinceDaysFromNow(Int32)
  /// On or before the day that many days from now.
  UntilDaysFromNow(Int32)
  /// From today through the day that many days from now.
  NextDays(Int32)
} derive(Eq, Debug)

///|
pub extend DateFilter with Eq::{equal, not_equal}

///|
pub extend DateFilter with @debug.Debug::{to_repr}

///|
fn DatePeriod::operator(self : DatePeriod) -> String {
  match self {
    Today => "t"
    Yesterday => "ld"
    ThisWeek => "w"
    LastWeek => "lw"
    LastTwoWeeks => "l2w"
    ThisMonth => "m"
    LastMonth => "lm"
    ThisYear => "y"
    Any => "*"
    Blank => "!*"
  }
}

///|
fn PastDateFilter::query_value(self : PastDateFilter) -> String {
  match self {
    On(day) => "=\{day}"
    Period(period) => period.operator()
    Between(from~, to~) => "><\{from}|\{to}"
    Since(day) => ">=\{day}"
    Until(day) => "<=\{day}"
    DaysAgo(days) => "t-\{days}"
    SinceDaysAgo(days) => ">t-\{days}"
    LastDays(days) => "><t-\{days}"
    UntilDaysAgo(days) => "<t-\{days}"
  }
}

///|
fn DateFilter::query_value(self : DateFilter) -> String {
  match self {
    Past(filter) => filter.query_value()
    Tomorrow => "nd"
    NextWeek => "nw"
    NextMonth => "nm"
    DaysFromNow(days) => "t+\{days}"
    SinceDaysFromNow(days) => ">t+\{days}"
    UntilDaysFromNow(days) => "<t+\{days}"
    NextDays(days) => "><t+\{days}"
  }
}
