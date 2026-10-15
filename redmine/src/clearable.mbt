///|
/// A value for an optional field that Redmine can also reset to empty.
/// An absent `Clearable[T]?` leaves the field alone, `Clear` empties it,
/// and `Set(value)` writes `value`.
pub(all) enum Clearable[T] {
  Set(T)
  Clear
} derive(Eq, Debug)

///|
pub extend Clearable with Eq::{equal, not_equal}

///|
pub extend Clearable with @debug.Debug::{to_repr}
