///|
/// A value for an optional field that Redmine can also reset to empty.
/// An absent `Clearable[T]?` leaves the field alone, `Clear` empties it,
/// and `Set(value)` writes `value`.
///
/// ```mbt check
/// test {
///   let assignee : @redmine.Clearable[Int32]? = Some(Set(7))
///   let unassigned : @redmine.Clearable[Int32]? = Some(Clear)
///   let untouched : @redmine.Clearable[Int32]? = None
///   assert_eq(assignee, Some(@redmine.Clearable::Set(7)))
///   assert_eq(unassigned, Some(@redmine.Clearable::Clear))
///   assert_true(untouched is None)
/// }
/// ```
pub(all) enum Clearable[T] {
  Set(T)
  Clear
} derive(Eq, Debug)

///|
pub extend Clearable with Eq::{equal, not_equal}

///|
pub extend Clearable with @debug.Debug::{to_repr}
