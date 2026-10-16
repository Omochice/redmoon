///|
/// Lists the issues matching `query`, fetching as many pages as needed.
/// With `limit`, at most that many issues are returned.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn list(
  redmine : @redmine.Redmine,
  query : ListQuery,
  limit? : Int32,
) -> Array[Issue] raise @redmine.RedmineError {
  @paging.list_all(
    redmine,
    ["issues.json"],
    key="issues",
    query=query.to_query(),
    limit?,
  )
}

///|
/// Shows an issue with the given associations.
/// Raises `RedmineError`, with status 404 when the issue does not exist.
pub async fn show(
  redmine : @redmine.Redmine,
  id : Int32,
  includes~ : Array[Include] = [],
) -> Issue raise @redmine.RedmineError {
  let query = if includes.is_empty() {
    []
  } else {
    [("include", include_value(includes.map(Include::name)))]
  }
  let json = redmine |> @redmine.send(Get, ["issues", "\{id}.json"], query~)
  @decode.decode_field(json, "issue")
}

///|
/// Creates an issue and returns it as Redmine stored it.
/// Raises `RedmineError`, with status 422 when Redmine rejects a field.
pub async fn create(
  redmine : @redmine.Redmine,
  issue : Create,
) -> Issue raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Post, ["issues.json"], body=issue.to_body())
  @decode.decode_field(json, "issue")
}

///|
/// Applies `update` to an issue.
/// Raises `RedmineError`, with status 404 when the issue does not exist.
pub async fn update(
  redmine : @redmine.Redmine,
  id : Int32,
  update : Update,
) -> Unit raise @redmine.RedmineError {
  ignore(
    redmine
    |> @redmine.send(Put, ["issues", "\{id}.json"], body=update.to_body()),
  )
}

///|
/// Deletes an issue.
/// Raises `RedmineError`, with status 404 when the issue does not exist.
pub async fn delete(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Unit raise @redmine.RedmineError {
  ignore(redmine |> @redmine.send(Delete, ["issues", "\{id}.json"]))
}

///|
/// Edits a comment of an issue: its text, its visibility, or both.
/// Redmine drops a comment whose notes become empty and that records no field change.
/// Raises `RedmineError`, with status 404 when the comment does not exist.
pub async fn update_journal(
  redmine : @redmine.Redmine,
  id : Int32,
  notes? : String,
  private_notes? : Bool,
) -> Unit raise @redmine.RedmineError {
  let journal = @wire.present_members([
    ("notes", notes.map(fn(v) { Json(v) })),
    ("private_notes", private_notes.map(fn(v) { Json(v) })),
  ])
  ignore(
    redmine
    |> @redmine.send(
      Put,
      ["journals", "\{id}.json"],
      body=Json::object({ "journal": journal }),
    ),
  )
}
