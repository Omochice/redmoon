///|
/// Which attachments a search includes, as Redmine's three-way `attachments` parameter.
pub(all) enum AttachmentScope {
  Excluded
  Included
  Only
} derive(Eq, Debug)

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
///
/// ```mbt check
/// test {
///   let query : @search.Query = {
///     q: "timeout",
///     scope: None,
///     all_words: None,
///     titles_only: Some(true),
///     open_issues: None,
///     issues: Some(true),
///     news: None,
///     documents: None,
///     changesets: None,
///     wiki_pages: None,
///     messages: None,
///     projects: None,
///     attachments: Some(Included),
///   }
///   assert_eq(query.attachments, Some(@search.AttachmentScope::Included))
/// }
/// ```
pub(all) struct Query {
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
} derive(Eq, Debug)

///|
pub extend Query with Eq::{equal, not_equal}

///|
pub extend Query with @debug.Debug::{to_repr}

///|
/// One match of a search. `kind` holds Redmine's `type` field, which MoonBit cannot name.
pub(all) struct Match {
  id : Int32
  title : String
  kind : String
  url : String
  description : String?
  datetime : String
} derive(Eq, Debug)

///|
pub extend Match with Eq::{equal, not_equal}

///|
pub extend Match with @debug.Debug::{to_repr}

///|
pub extend Match with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for Match with fn from_json(json, path) {
  guard json is Object(members) else {
    raise @json.JsonDecodeError((path, "Match::from_json: expected object"))
  }
  {
    id: @wire.json_member(members, "id", path),
    title: @wire.json_member(members, "title", path),
    kind: @wire.json_member(members, "type", path),
    url: @wire.json_member(members, "url", path),
    description: @wire.json_member(members, "description", path),
    datetime: @wire.json_member(members, "datetime", path),
  }
}

///|
pub extend Match with ToJson::{to_json}

///|
/// `description` is written as `null` when absent, as the tool output has always carried it.
pub impl ToJson for Match with fn to_json(self) {
  {
    "id": self.id,
    "title": self.title,
    "type": self.kind,
    "url": self.url,
    "description": self.description
    .map(fn(text) { Json(text) })
    .unwrap_or(Json::null()),
    "datetime": self.datetime,
  }
}

///|
/// Searches the resources Redmine indexes and returns the matches, up to `limit` when given.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let query : @search.Query = {
///     q: "timeout",
///     scope: None,
///     all_words: None,
///     titles_only: None,
///     open_issues: Some(true),
///     issues: Some(true),
///     news: None,
///     documents: None,
///     changesets: None,
///     wiki_pages: None,
///     messages: None,
///     projects: None,
///     attachments: None,
///   }
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
