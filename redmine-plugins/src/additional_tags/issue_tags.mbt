///|
const ISSUE_TAGS_ABSENT : String = "the Additional Tags plugin is not installed, its issue tags are switched off, or the user lacks the view_issue_tags permission"

///|
const ISSUE_TAGS_DROPPED : String = "this happens without the edit_issue_tags permission, without create_issue_tags for a name no issue carries yet, or while the plugin's issue tags setting is switched off"

///|
/// Only `issue.tags` is decoded, so that reading tags does not depend on how `@issues.Issue` decodes the rest of the issue.
fn issue_tags_in(json : Json) -> Array[String] raise @redmine.RedmineError {
  let issue : Json = @decode.decode_field(json, "issue")
  names_in(issue, absent=ISSUE_TAGS_ABSENT)
}

///|
/// A comma-separated string is rejected for a user without create_issue_tags even when every tag exists, while the same names as an array are accepted.
fn tag_list_body(names : Array[String]) -> Json {
  { "issue": { "tag_list": Json(names) } }
}

///|
/// The tag names of the issue `issue_id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure, and `Decode` when the answer has no tags because the plugin is not installed, its issue tags are switched off, or the user lacks `view_issue_tags`.
///
/// ```mbt check
/// #skip("needs a live Redmine with the Additional Tags plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let names = redmine |> @additional_tags.tags(42)
///   ignore(names)
/// }
/// ```
pub async fn tags(
  redmine : @redmine.Redmine,
  issue_id : Int32,
) -> Array[String] raise @redmine.RedmineError {
  redmine |> @redmine.send(Get, ["issues", "\{issue_id}.json"]) |> issue_tags_in
}

///|
async fn change_issue_tags(
  redmine : @redmine.Redmine,
  issue_id : Int32,
  change : Change,
  names : Array[String],
) -> Array[String] raise @redmine.RedmineError {
  change.apply(
    names,
    read=() => tags(redmine, issue_id),
    write=next => {
      ignore(
        redmine
        |> @redmine.send(
          Put,
          ["issues", "\{issue_id}.json"],
          body=tag_list_body(next),
        ),
      )
    },
    causes=ISSUE_TAGS_DROPPED,
  )
}

///|
/// Adds `names` to the tags of the issue `issue_id`, skipping those it carries in any case, and returns its tag names after the write.
/// Nothing is written when the issue already carries every name.
/// Raises `InvalidArgument` before any request when `names` is empty or a name is blank or contains a comma.
/// Raises `Decode` when Redmine accepted the update without saving the tags, which happens without `edit_issue_tags`, without `create_issue_tags` for a name no issue carries yet, or while the plugin's issue tags are switched off, and in the cases `tags` raises it.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine with the Additional Tags plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let names = redmine |> @additional_tags.add(42, ["needs-review"])
///   ignore(names)
/// }
/// ```
pub async fn add(
  redmine : @redmine.Redmine,
  issue_id : Int32,
  names : Array[String],
) -> Array[String] raise @redmine.RedmineError {
  change_issue_tags(redmine, issue_id, Add, names)
}

///|
/// Removes the tags of the issue `issue_id` that match any of `names` in any case, and returns its tag names after the write.
/// Nothing is written when the issue carries none of the names.
/// Raises `InvalidArgument` before any request when `names` is empty or a name is blank or contains a comma.
/// Raises `Decode` when Redmine accepted the update without saving the tags, which happens without `edit_issue_tags` or while the plugin's issue tags are switched off, and in the cases `tags` raises it.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine with the Additional Tags plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let names = redmine |> @additional_tags.remove(42, ["needs-review"])
///   ignore(names)
/// }
/// ```
pub async fn remove(
  redmine : @redmine.Redmine,
  issue_id : Int32,
  names : Array[String],
) -> Array[String] raise @redmine.RedmineError {
  change_issue_tags(redmine, issue_id, Remove, names)
}

///|
/// Every issue tag with the number of issues that carry it.
/// Only a Redmine administrator may read it; for anyone else it raises `Response` with status 403 and a message saying so.
/// Raises `RedmineError` on any other non-2xx answer, an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine with the Additional Tags plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let tags = redmine |> @additional_tags.list()
///   ignore(tags)
/// }
/// ```
pub async fn list(
  redmine : @redmine.Redmine,
) -> Array[Tag] raise @redmine.RedmineError {
  catalogue(redmine, "issue")
}

///|
/// Redmine ignores the `status_id` shorthand once `f[]` is given and then lists issues of every status, so the status goes in as a filter of its own.
/// Open issues are asked for when no status is given, as the issue list does by default.
fn issues_query(
  names : Array[String],
  project_id? : Int32,
  status_id~ : @issues.StatusFilter = Open,
) -> Array[(String, String)] {
  let query = [("set_filter", "1"), ("f[]", "tags"), ("op[tags]", "=")]
  for name in names {
    query.push(("v[tags][]", name))
  }
  query.push(("f[]", "status_id"))
  match status_id {
    Open => query.push(("op[status_id]", "o"))
    Closed => query.push(("op[status_id]", "c"))
    All => query.push(("op[status_id]", "*"))
    Id(id) => {
      query.push(("op[status_id]", "="))
      query.push(("v[status_id][]", id.to_string()))
    }
  }
  if project_id is Some(id) {
    query.push(("project_id", id.to_string()))
  }
  query
}

///|
/// The issues carrying any of `names`, matched in any case, narrowed by project and status as `@issues.list` narrows them.
/// Only open issues are listed unless `status_id` says otherwise, and at most `limit` issues are returned when it is given.
/// The issues carry no tags; `tags` reads them.
/// Raises `InvalidArgument` before any request when `names` is empty or a name is blank or contains a comma.
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine with the Additional Tags plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let issues = redmine
///     |> @additional_tags.list_issues(["needs-review"], project_id=1, limit=20)
///   ignore(issues)
/// }
/// ```
pub async fn list_issues(
  redmine : @redmine.Redmine,
  names : Array[String],
  project_id? : Int32,
  status_id? : @issues.StatusFilter,
  limit? : Int32,
) -> Array[@issues.Issue] raise @redmine.RedmineError {
  @paging.list_all(
    redmine,
    ["issues.json"],
    key="issues",
    query=issues_query(validate(names), project_id?, status_id?),
    limit?,
  )
}
