///|
/// Which attachments a search includes, as Redmine's three-way `attachments` parameter.
#derive(Eq, Debug)
pub(all) enum AttachmentScope {
  Excluded
  Included
  Only
}

///|
pub extend AttachmentScope with Eq::{equal, not_equal}

///|
pub extend AttachmentScope with @debug.Debug::{to_repr}

///|
fn AttachmentScope::to_wire(self : AttachmentScope) -> String {
  match self {
    Excluded => "0"
    Included => "1"
    Only => "only"
  }
}

///|
/// The parameters of a search. A `None` flag is left out of the request, which keeps Redmine's default for it.
#derive(Eq, Debug)
pub struct Query {
  q : String
  scope : String?
  all_words : Bool?
  titles_only : Bool?
  open_issues : Bool?
  issues : Bool?
  news : Bool?
  documents : Bool?
  changesets : Bool?
  wiki_pages : Bool?
  messages : Bool?
  projects : Bool?
  attachments : AttachmentScope?
}

///|
pub extend Query with Eq::{equal, not_equal}

///|
pub extend Query with @debug.Debug::{to_repr}

///|
/// The parameters of a search; only `q` must be given.
///
/// ```mbt check
/// test {
///   let query = @search.Query::new(
///     q="timeout",
///     titles_only=true,
///     issues=true,
///     attachments=Included,
///   )
///   assert_eq(query.attachments, Some(@search.AttachmentScope::Included))
///   assert_true(query.scope is None)
/// }
/// ```
pub fn Query::new(
  q~ : String,
  scope? : String,
  all_words? : Bool,
  titles_only? : Bool,
  open_issues? : Bool,
  issues? : Bool,
  news? : Bool,
  documents? : Bool,
  changesets? : Bool,
  wiki_pages? : Bool,
  messages? : Bool,
  projects? : Bool,
  attachments? : AttachmentScope,
) -> Query {
  {
    q,
    scope,
    all_words,
    titles_only,
    open_issues,
    issues,
    news,
    documents,
    changesets,
    wiki_pages,
    messages,
    projects,
    attachments,
  }
}

///|
/// One match of a search. `kind` holds Redmine's `type` field, which MoonBit cannot name.
#derive(Eq, Debug, FromJson(fields(kind(rename="type"))), ToJson(fields(kind(rename="type"))))
pub(all) struct Match {
  id : Int32
  title : String
  kind : String
  url : String
  description : String?
  datetime : String
}

///|
pub extend Match with Eq::{equal, not_equal}

///|
pub extend Match with @debug.Debug::{to_repr}

///|
pub extend Match with @json.FromJson::{from_json}

///|
pub extend Match with ToJson::{to_json}

///|
/// Searches the resources Redmine indexes and returns the matches, up to `limit` when given.
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let query = @search.Query::new(q="timeout", open_issues=true, issues=true)
///   let matches = redmine |> @search.search(query, limit=20)
///   ignore(matches)
/// }
/// ```
pub async fn search(
  redmine : @redmine.Redmine,
  query : Query,
  limit? : Int32,
) -> Array[Match] raise @redmine.RedmineError {
  @paging.list_all(
    redmine,
    ["search.json"],
    key="results",
    query=query_pairs(query),
    limit?,
  )
}

///|
fn query_pairs(query : Query) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = [("q", query.q)]
  if query.scope is Some(scope) {
    pairs.push(("scope", scope))
  }
  if query.all_words is Some(all_words) {
    pairs.push(("all_words", if all_words { "1" } else { "" }))
  }
  push_flag(pairs, "titles_only", query.titles_only)
  push_flag(pairs, "open_issues", query.open_issues)
  push_flag(pairs, "issues", query.issues)
  push_flag(pairs, "news", query.news)
  push_flag(pairs, "documents", query.documents)
  push_flag(pairs, "changesets", query.changesets)
  push_flag(pairs, "wiki_pages", query.wiki_pages)
  push_flag(pairs, "messages", query.messages)
  push_flag(pairs, "projects", query.projects)
  if query.attachments is Some(scope) {
    pairs.push(("attachments", scope.to_wire()))
  }
  pairs
}

///|
/// Unlike `all_words`, a flag is sent only when true, because Redmine enables a flag as soon as its parameter is present.
fn push_flag(
  pairs : Array[(String, String)],
  name : String,
  flag : Bool?,
) -> Unit {
  if flag is Some(true) {
    pairs.push((name, "1"))
  }
}
