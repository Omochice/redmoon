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
pub async fn Redmine::list_time_entry_activities(
  self : Redmine,
) -> Array[Enumeration] raise RedmineError {
  self.list_enumerations("time_entry_activities")
}

///|
/// Lists the issue priorities.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::list_issue_priorities(
  self : Redmine,
) -> Array[Enumeration] raise RedmineError {
  self.list_enumerations("issue_priorities")
}

///|
/// Lists the document categories.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::list_document_categories(
  self : Redmine,
) -> Array[Enumeration] raise RedmineError {
  self.list_enumerations("document_categories")
}

///|
async fn Redmine::list_enumerations(
  self : Redmine,
  kind : String,
) -> Array[Enumeration] raise RedmineError {
  let json = self.get(["enumerations", kind + ".json"])
  decode_field(json, kind)
}
