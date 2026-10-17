///|
/// A time entry logged against a project, optionally an issue.
pub(all) struct Entry {
  id : Int32
  project : @redmine.IdName
  issue : Issue?
  user : @redmine.IdName
  activity : @redmine.IdName
  hours : Double
  comments : String?
  spent_on : String
  created_on : String
  updated_on : String
  custom_fields : Array[CustomField]?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Entry with @json.FromJson::{from_json}

///|
pub extend Entry with ToJson::{to_json}

///|
pub extend Entry with Eq::{equal, not_equal}

///|
pub extend Entry with @debug.Debug::{to_repr}

///|
/// The issue a time entry is logged against, as Redmine references it.
pub(all) struct Issue {
  id : Int32
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Issue with @json.FromJson::{from_json}

///|
pub extend Issue with ToJson::{to_json}

///|
pub extend Issue with Eq::{equal, not_equal}

///|
pub extend Issue with @debug.Debug::{to_repr}

///|
/// A custom field value attached to a time entry.
pub(all) struct CustomField {
  id : Int32
  name : String
  value : Json?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend CustomField with @json.FromJson::{from_json}

///|
pub extend CustomField with ToJson::{to_json}

///|
pub extend CustomField with Eq::{equal, not_equal}

///|
pub extend CustomField with @debug.Debug::{to_repr}

///|
/// Filters for listing time entries; `None` leaves a filter out.
/// `spent_on`, `from`, and `to` are ISO dates (`YYYY-MM-DD`).
///
/// ```mbt check
/// test {
///   let query : @time_entries.ListQuery = {
///     project_id: Some(1),
///     user_id: None,
///     spent_on: None,
///     from: Some("2026-10-01"),
///     to: Some("2026-10-31"),
///   }
///   assert_eq(query.from, Some("2026-10-01"))
/// }
/// ```
pub(all) struct ListQuery {
  project_id : Int32?
  user_id : Int32?
  spent_on : String?
  from : String?
  to : String?
} derive(Eq, Debug)

///|
pub extend ListQuery with Eq::{equal, not_equal}

///|
pub extend ListQuery with @debug.Debug::{to_repr}

///|
/// Lists the time entries matching `query`, following every page unless `limit` caps the count.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let query : @time_entries.ListQuery = {
///     project_id: Some(1),
///     user_id: None,
///     spent_on: None,
///     from: Some("2026-10-01"),
///     to: Some("2026-10-31"),
///   }
///   let entries = redmine |> @time_entries.list(query, limit=50)
///   ignore(entries)
/// }
/// ```
pub async fn list(
  redmine : @redmine.Redmine,
  query : ListQuery,
  limit? : Int32,
) -> Array[Entry] raise @redmine.RedmineError {
  @paging.list_all(
    redmine,
    ["time_entries.json"],
    key="time_entries",
    query=query.to_pairs(),
    limit?,
  )
}

///|
/// Maps the set filters to Redmine's query parameter names.
fn ListQuery::to_pairs(self : ListQuery) -> Array[(String, String)] {
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

///|
/// The attributes of a time entry to log. `hours` is required by Redmine; `None` fields are left out of the request.
///
/// ```mbt check
/// test {
///   let create : @time_entries.Create = {
///     hours: 1.5,
///     issue_id: Some(42),
///     project_id: None,
///     spent_on: Some("2026-10-17"),
///     activity_id: None,
///     comments: Some("Investigated the timeout"),
///   }
///   assert_eq(create.hours, 1.5)
/// }
/// ```
pub(all) struct Create {
  hours : Double
  issue_id : Int32?
  project_id : Int32?
  spent_on : String?
  activity_id : Int32?
  comments : String?
} derive(ToJson, Eq, Debug)

///|
pub extend Create with ToJson::{to_json}

///|
pub extend Create with Eq::{equal, not_equal}

///|
pub extend Create with @debug.Debug::{to_repr}

///|
/// The attributes of a time entry to change; `None` fields are left out of the request.
///
/// ```mbt check
/// test {
///   let update : @time_entries.Update = {
///     hours: Some(2.0),
///     issue_id: None,
///     project_id: None,
///     spent_on: None,
///     activity_id: None,
///     comments: None,
///   }
///   assert_eq(update.hours, Some(2.0))
/// }
/// ```
pub(all) struct Update {
  hours : Double?
  issue_id : Int32?
  project_id : Int32?
  spent_on : String?
  activity_id : Int32?
  comments : String?
} derive(ToJson, Eq, Debug)

///|
pub extend Update with ToJson::{to_json}

///|
pub extend Update with Eq::{equal, not_equal}

///|
pub extend Update with @debug.Debug::{to_repr}

///|
/// Shows the time entry with `id`.
/// Raises `RedmineError` on a non-2xx answer (404 when it does not exist) or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let entry = (redmine |> @time_entries.show(9)) catch {
///     @redmine.Response(status=404, ..) => return
///     error => raise error
///   }
///   ignore(entry)
/// }
/// ```
pub async fn show(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Entry raise @redmine.RedmineError {
  let json = redmine |> @redmine.send(Get, ["time_entries", "\{id}.json"])
  @decode.decode_field(json, "time_entry")
}

///|
/// Logs a time entry and returns it as Redmine stored it.
/// Raises `RedmineError` on a non-2xx answer (422 for invalid attributes) or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let entry = redmine
///     |> @time_entries.create({
///       hours: 1.5,
///       issue_id: Some(42),
///       project_id: None,
///       spent_on: None,
///       activity_id: None,
///       comments: Some("Investigated the timeout"),
///     })
///   ignore(entry)
/// }
/// ```
pub async fn create(
  redmine : @redmine.Redmine,
  time_entry : Create,
) -> Entry raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Post, ["time_entries.json"], body=entry_body(time_entry))
  @decode.decode_field(json, "time_entry")
}

///|
/// Changes the time entry with `id`.
/// Raises `RedmineError` on a non-2xx answer (404 when it does not exist, 422 for invalid attributes) or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine
///   |> @time_entries.update(9, {
///     hours: Some(2.0),
///     issue_id: None,
///     project_id: None,
///     spent_on: None,
///     activity_id: None,
///     comments: None,
///   })
/// }
/// ```
pub async fn update(
  redmine : @redmine.Redmine,
  id : Int32,
  time_entry : Update,
) -> Unit raise @redmine.RedmineError {
  ignore(
    redmine
    |> @redmine.send(
      Put,
      ["time_entries", "\{id}.json"],
      body=entry_body(time_entry),
    ),
  )
}

///|
/// Deletes the time entry with `id`.
/// Raises `RedmineError` on a non-2xx answer (404 when it does not exist) or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine |> @time_entries.delete(9)
/// }
/// ```
pub async fn delete(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Unit raise @redmine.RedmineError {
  ignore(redmine |> @redmine.send(Delete, ["time_entries", "\{id}.json"]))
}

///|
/// Wraps a time entry's attributes in the `{"time_entry": ...}` envelope Redmine expects.
fn[T : ToJson] entry_body(attributes : T) -> Json {
  Json::object({ "time_entry": ToJson::to_json(attributes) })
}
