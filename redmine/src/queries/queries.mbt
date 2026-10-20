///|
/// A saved issue query; `project_id` is `None` for a query shared by every project.
pub(all) struct Query {
  id : Int32
  name : String
  is_public : Bool
  project_id : Int32?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Query with @json.FromJson::{from_json}

///|
pub extend Query with ToJson::{to_json}

///|
pub extend Query with Eq::{equal, not_equal}

///|
pub extend Query with @debug.Debug::{to_repr}

///|
/// Lists the saved issue queries the user can see, global and project ones alike.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let queries = redmine |> @queries.list()
///   ignore(queries)
/// }
/// ```
pub async fn list(
  redmine : @redmine.Redmine,
) -> Array[Query] raise @redmine.RedmineError {
  // Redmine ignores project_id here and answers 404 under /projects/:id, so there is no way to ask for one project's queries.
  @paging.list_all(redmine, ["queries.json"], key="queries")
}
