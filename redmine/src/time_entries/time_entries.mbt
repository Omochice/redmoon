///|
/// A time entry logged against a project, optionally an issue.
#derive(FromJson, ToJson, Eq, Debug)
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
}

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
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct Issue {
  id : Int32
}

///|
pub extend Issue with @json.FromJson::{from_json}

///|
pub extend Issue with ToJson::{to_json}

///|
pub extend Issue with Eq::{equal, not_equal}

///|
pub extend Issue with @debug.Debug::{to_repr}

///|
/// A custom field as it appears on a time entry.
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct CustomField {
  id : Int32
  name : String
  value : @redmine.CustomFieldValue?
}

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
#derive(Eq, Debug)
pub struct ListQuery {
  project_id : Int32?
  user_id : Int32?
  spent_on : String?
  from : String?
  to : String?
}

///|
pub extend ListQuery with Eq::{equal, not_equal}

///|
pub extend ListQuery with @debug.Debug::{to_repr}

///|
/// Conditions for `list`; an unset condition does not filter.
///
/// ```mbt check
/// test {
///   let query = @time_entries.ListQuery::new(
///     project_id=1,
///     from="2026-10-01",
///     to="2026-10-31",
///   )
///   assert_eq(query.from, Some("2026-10-01"))
///   assert_true(query.user_id is None)
/// }
/// ```
pub fn ListQuery::new(
  project_id? : Int32,
  user_id? : Int32,
  spent_on? : String,
  from? : String,
  to? : String,
) -> ListQuery {
  { project_id, user_id, spent_on, from, to, }
}

///|
/// Lists the time entries matching `query`, following every page unless `limit` caps the count.
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let query = @time_entries.ListQuery::new(
///     project_id=1,
///     from="2026-10-01",
///     to="2026-10-31",
///   )
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
#derive(ToJson, Eq, Debug)
pub struct Create {
  hours : Double
  issue_id : Int32?
  project_id : Int32?
  spent_on : String?
  activity_id : Int32?
  comments : String?
}

///|
pub extend Create with ToJson::{to_json}

///|
pub extend Create with Eq::{equal, not_equal}

///|
pub extend Create with @debug.Debug::{to_repr}

///|
/// The attributes of a time entry to log; only `hours` must be given, and Redmine needs `issue_id` or `project_id` besides.
///
/// ```mbt check
/// test {
///   let create = @time_entries.Create::new(
///     hours=1.5,
///     issue_id=42,
///     spent_on="2026-10-17",
///     comments="Investigated the timeout",
///   )
///   assert_eq(create.hours, 1.5)
///   assert_true(create.project_id is None)
/// }
/// ```
pub fn Create::new(
  hours~ : Double,
  issue_id? : Int32,
  project_id? : Int32,
  spent_on? : String,
  activity_id? : Int32,
  comments? : String,
) -> Create {
  { hours, issue_id, project_id, spent_on, activity_id, comments, }
}

///|
/// The attributes of a time entry to change; `None` fields are left out of the request.
/// `Clear` detaches the entry from its issue, which leaves it on the project, or empties the comments.
#derive(Eq, Debug)
pub struct Update {
  hours : Double?
  issue_id : @redmine.Clearable[Int32]?
  project_id : Int32?
  spent_on : String?
  activity_id : Int32?
  comments : @redmine.Clearable[String]?
}

///|
pub extend Update with Eq::{equal, not_equal}

///|
pub extend Update with @debug.Debug::{to_repr}

///|
/// The attributes of a time entry to change; only the fields given are touched.
///
/// ```mbt check
/// test {
///   let update = @time_entries.Update::new(hours=2.0, comments=Clear)
///   assert_eq(update.hours, Some(2.0))
///   assert_eq(update.comments, Some(@redmine.Clearable::Clear))
///   assert_true(update.issue_id is None)
/// }
/// ```
pub fn Update::new(
  hours? : Double,
  issue_id? : @redmine.Clearable[Int32],
  project_id? : Int32,
  spent_on? : String,
  activity_id? : Int32,
  comments? : @redmine.Clearable[String],
) -> Update {
  { hours, issue_id, project_id, spent_on, activity_id, comments, }
}

///|
/// Shows the time entry with `id`.
/// Raises `RedmineError` on a non-2xx answer (404 when it does not exist), an unreadable 2xx answer, or a transport failure.
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
/// Raises `RedmineError` on a non-2xx answer (422 for invalid attributes), an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let entry = redmine
///     |> @time_entries.create(
///       @time_entries.Create::new(
///         hours=1.5,
///         issue_id=42,
///         comments="Investigated the timeout",
///       ),
///     )
///   ignore(entry)
/// }
/// ```
pub async fn create(
  redmine : @redmine.Redmine,
  time_entry : Create,
) -> Entry raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Post, ["time_entries.json"], body=time_entry.to_body())
  @decode.decode_field(json, "time_entry")
}

///|
/// Changes the time entry with `id`.
/// Raises `RedmineError` on a non-2xx answer (404 when it does not exist, 422 for invalid attributes), an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine |> @time_entries.update(9, @time_entries.Update::new(hours=2.0))
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
      body=time_entry.to_body(),
    ),
  )
}

///|
/// Deletes the time entry with `id`.
/// Raises `RedmineError` on a non-2xx answer (404 when it does not exist), an unreadable 2xx answer, or a transport failure.
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
fn Create::to_body(self : Create) -> Json {
  let time_entry = @wire.present_members([
    ("hours", Some(ToJson::to_json(self.hours))),
    ("issue_id", self.issue_id.map(ToJson::to_json)),
    ("project_id", self.project_id.map(ToJson::to_json)),
    ("spent_on", self.spent_on.map(ToJson::to_json)),
    ("activity_id", self.activity_id.map(ToJson::to_json)),
    ("comments", self.comments.map(ToJson::to_json)),
  ])
  Json::object({ "time_entry": time_entry })
}

///|
fn Update::to_body(self : Update) -> Json {
  let time_entry = @wire.present_members([
    ("hours", self.hours.map(ToJson::to_json)),
    (
      "issue_id",
      @redmine.Clearable::to_member(self.issue_id, set=ToJson::to_json),
    ),
    ("project_id", self.project_id.map(ToJson::to_json)),
    ("spent_on", self.spent_on.map(ToJson::to_json)),
    ("activity_id", self.activity_id.map(ToJson::to_json)),
    (
      "comments",
      @redmine.Clearable::to_member(self.comments, set=ToJson::to_json),
    ),
  ])
  Json::object({ "time_entry": time_entry })
}
