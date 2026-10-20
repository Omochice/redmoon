///|
/// Lists the issues `selection` picks, fetching as many pages as needed.
/// With `limit`, at most that many issues are returned.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let query = @issues.ListQuery::new(
///     project_id=1,
///     status_id=Open,
///     assigned_to_id=Me,
///   )
///   let issues = redmine |> @issues.list(query, limit=10)
///   ignore(issues)
/// }
/// ```
pub async fn[S : Selection] list(
  redmine : @redmine.Redmine,
  selection : S,
  limit? : Int32,
) -> Array[Issue] raise @redmine.RedmineError {
  @paging.list_all(
    redmine,
    ["issues.json"],
    key="issues",
    query=selection.to_query(),
    limit?,
  )
}

///|
/// Shows an issue with the given associations.
/// Raises `RedmineError`, with status 404 when the issue does not exist.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let issue = (redmine |> @issues.show(42, includes=[Journals, Attachments])) catch {
///     @redmine.Response(status=404, ..) => return
///     error => raise error
///   }
///   ignore(issue)
/// }
/// ```
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
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let issue = redmine
///     |> @issues.create(
///       @issues.Create::new(
///         project_id=1,
///         tracker_id=1,
///         status_id=1,
///         priority_id=2,
///         subject="Login page returns 500",
///       ),
///     )
///   ignore(issue)
/// }
/// ```
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
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine
///   |> @issues.update(
///     42,
///     @issues.Update::new(notes="Fixed in 1.2", assigned_to_id=Clear),
///   )
/// }
/// ```
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
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine |> @issues.delete(42)
/// }
/// ```
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
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine |> @issues.update_journal(7, notes="Corrected comment")
/// }
/// ```
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
