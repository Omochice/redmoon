///|
/// Lists the issues matching `query`, fetching as many pages as needed.
/// With `limit`, at most that many issues are returned.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::list_issues(
  self : Redmine,
  query : IssueListQuery,
  limit? : Int32,
) -> Array[Issue] raise RedmineError {
  self.list_all(["issues.json"], key="issues", query=query.to_query(), limit?)
}

///|
/// Shows an issue with the given associations.
/// Raises `RedmineError`, with status 404 when the issue does not exist.
pub async fn Redmine::show_issue(
  self : Redmine,
  id : Int32,
  includes~ : Array[IssueInclude] = [],
) -> Issue raise RedmineError {
  let query = if includes.is_empty() {
    []
  } else {
    [("include", include_value(includes.map(IssueInclude::name)))]
  }
  decode_field(self.get(["issues", "\{id}.json"], query~), "issue")
}

///|
/// Creates an issue and returns it as Redmine stored it.
/// Raises `RedmineError`, with status 422 when Redmine rejects a field.
pub async fn Redmine::create_issue(
  self : Redmine,
  issue : IssueCreate,
) -> Issue raise RedmineError {
  decode_field(self.send(Post, ["issues.json"], body=issue.to_body()), "issue")
}

///|
/// Applies `update` to an issue.
/// Raises `RedmineError`, with status 404 when the issue does not exist.
pub async fn Redmine::update_issue(
  self : Redmine,
  id : Int32,
  update : IssueUpdate,
) -> Unit raise RedmineError {
  ignore(self.send(Put, ["issues", "\{id}.json"], body=update.to_body()))
}

///|
/// Deletes an issue.
/// Raises `RedmineError`, with status 404 when the issue does not exist.
pub async fn Redmine::delete_issue(
  self : Redmine,
  id : Int32,
) -> Unit raise RedmineError {
  ignore(self.send(Delete, ["issues", "\{id}.json"]))
}

///|
/// Edits a comment of an issue: its text, its visibility, or both.
/// Redmine drops a comment whose notes become empty and that records no field change.
/// Raises `RedmineError`, with status 404 when the comment does not exist.
pub async fn Redmine::update_journal(
  self : Redmine,
  id : Int32,
  notes? : String,
  private_notes? : Bool,
) -> Unit raise RedmineError {
  let journal = present_members([
    ("notes", notes.map(fn(v) { Json(v) })),
    ("private_notes", private_notes.map(fn(v) { Json(v) })),
  ])
  ignore(
    self.send(
      Put,
      ["journals", "\{id}.json"],
      body=Json::object({ "journal": journal }),
    ),
  )
}
