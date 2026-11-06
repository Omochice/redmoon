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
#derive(Eq, Debug)
pub(all) enum Clearable[T] {
  Set(T)
  Clear
}

///|
pub extend Clearable with Eq::{equal, not_equal}

///|
pub extend Clearable with @debug.Debug::{to_repr}

///|
/// Encodes a `Clearable` field as a request member for `present_members`.
/// `clear` defaults to `null`, which is how Redmine empties most fields; a field Redmine empties another way, such as `assigned_to_id`, passes its own.
///
/// ```mbt check
/// test {
///   let cleared = @redmine.Clearable::to_member(Some(Clear), set=(id : Int32) => {
///     Json(id)
///   })
///   assert_eq(cleared, Some(Json::null()))
///   let untouched = @redmine.Clearable::to_member(None, set=(id : Int32) => {
///     Json(id)
///   })
///   assert_true(untouched is None)
/// }
/// ```
pub fn[T] Clearable::to_member(
  clearable : Clearable[T]?,
  clear~ : Json = Json::null(),
  set~ : (T) -> Json,
) -> Json? {
  match clearable {
    None => None
    Some(Clear) => Some(clear)
    Some(Set(value)) => Some(set(value))
  }
}
