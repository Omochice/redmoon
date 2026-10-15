///|
/// A time entry logged against a project, optionally an issue.
pub(all) struct TimeEntry {
  id : Int32
  project : IdName
  issue : TimeEntryIssue?
  user : IdName
  activity : IdName
  hours : Double
  comments : String?
  spent_on : String
  created_on : String
  updated_on : String
  custom_fields : Array[TimeEntryCustomField]?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend TimeEntry with @json.FromJson::{from_json}

///|
pub extend TimeEntry with ToJson::{to_json}

///|
pub extend TimeEntry with Eq::{equal, not_equal}

///|
pub extend TimeEntry with @debug.Debug::{to_repr}

///|
/// The issue a time entry is logged against, as Redmine references it.
pub(all) struct TimeEntryIssue {
  id : Int32
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend TimeEntryIssue with @json.FromJson::{from_json}

///|
pub extend TimeEntryIssue with ToJson::{to_json}

///|
pub extend TimeEntryIssue with Eq::{equal, not_equal}

///|
pub extend TimeEntryIssue with @debug.Debug::{to_repr}

///|
/// A custom field value attached to a time entry.
pub(all) struct TimeEntryCustomField {
  id : Int32
  name : String
  value : Json?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend TimeEntryCustomField with @json.FromJson::{from_json}

///|
pub extend TimeEntryCustomField with ToJson::{to_json}

///|
pub extend TimeEntryCustomField with Eq::{equal, not_equal}

///|
pub extend TimeEntryCustomField with @debug.Debug::{to_repr}

///|
/// Filters for listing time entries; `None` leaves a filter out.
/// `spent_on`, `from`, and `to` are ISO dates (`YYYY-MM-DD`).
pub(all) struct TimeEntryListQuery {
  project_id : Int32?
  user_id : Int32?
  spent_on : String?
  from : String?
  to : String?
} derive(Eq, Debug)

///|
pub extend TimeEntryListQuery with Eq::{equal, not_equal}

///|
pub extend TimeEntryListQuery with @debug.Debug::{to_repr}

///|
/// Lists the time entries matching `query`, following every page unless `limit` caps the count.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::list_time_entries(
  self : Redmine,
  query : TimeEntryListQuery,
  limit? : Int32,
) -> Array[TimeEntry] raise RedmineError {
  self.list_all(
    ["time_entries.json"],
    key="time_entries",
    query=query.to_pairs(),
    limit?,
  )
}

///|
/// Maps the set filters to Redmine's query parameter names.
fn TimeEntryListQuery::to_pairs(
  self : TimeEntryListQuery,
) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  if self.project_id is Some(id) {
    pairs.push(("project_id", id.to_string()))
  }
  if self.user_id is Some(id) {
    pairs.push(("user_id", id.to_string()))
  }
  if self.spent_on is Some(date) {
    pairs.push(("spent_on", date))
  }
  if self.from is Some(date) {
    pairs.push(("from", date))
  }
  if self.to is Some(date) {
    pairs.push(("to", date))
  }
  pairs
}
