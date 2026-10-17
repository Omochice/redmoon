///|
/// A Redmine enumeration value: an issue priority, time entry activity, or document category.
pub(all) struct Enumeration {
  id : Int32
  name : String
  is_default : Bool
  active : Bool
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Enumeration with @json.FromJson::{from_json}

///|
pub extend Enumeration with ToJson::{to_json}

///|
pub extend Enumeration with Eq::{equal, not_equal}

///|
pub extend Enumeration with @debug.Debug::{to_repr}

///|
/// Lists the time entry activities.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let activities = redmine |> @enumerations.time_entry_activities()
///   ignore(activities)
/// }
/// ```
pub async fn time_entry_activities(
  redmine : @redmine.Redmine,
) -> Array[Enumeration] raise @redmine.RedmineError {
  list(redmine, "time_entry_activities")
}

///|
/// Lists the issue priorities.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let priorities = redmine |> @enumerations.issue_priorities()
///   ignore(priorities)
/// }
/// ```
pub async fn issue_priorities(
  redmine : @redmine.Redmine,
) -> Array[Enumeration] raise @redmine.RedmineError {
  list(redmine, "issue_priorities")
}

///|
/// Lists the document categories.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let categories = redmine |> @enumerations.document_categories()
///   ignore(categories)
/// }
/// ```
pub async fn document_categories(
  redmine : @redmine.Redmine,
) -> Array[Enumeration] raise @redmine.RedmineError {
  list(redmine, "document_categories")
}

///|
async fn list(
  redmine : @redmine.Redmine,
  kind : String,
) -> Array[Enumeration] raise @redmine.RedmineError {
  let json = redmine |> @redmine.send(Get, ["enumerations", kind + ".json"])
  @decode.decode_field(json, kind)
}
