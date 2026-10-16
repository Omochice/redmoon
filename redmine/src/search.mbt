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
pub(all) struct SearchQuery {
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
pub extend SearchQuery with Eq::{equal, not_equal}

///|
pub extend SearchQuery with @debug.Debug::{to_repr}

///|
/// One match of a search. `kind` holds Redmine's `type` field, which MoonBit cannot name.
pub(all) struct SearchResult {
  id : Int32
  title : String
  kind : String
  url : String
  description : String?
  datetime : String
} derive(Eq, Debug)

///|
pub extend SearchResult with Eq::{equal, not_equal}

///|
pub extend SearchResult with @debug.Debug::{to_repr}

///|
pub extend SearchResult with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for SearchResult with fn from_json(json, path) {
  guard json is Object(members) else {
    raise @json.JsonDecodeError(
      (path, "SearchResult::from_json: expected object"),
    )
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
pub extend SearchResult with ToJson::{to_json}

///|
/// `description` is written as `null` when absent, as the tool output has always carried it.
pub impl ToJson for SearchResult with fn to_json(self) {
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
pub async fn Redmine::search(
  self : Redmine,
  query : SearchQuery,
  limit? : Int32,
) -> Array[SearchResult] raise RedmineError {
  self.list_all(
    ["search.json"],
    key="results",
    query=search_query_pairs(query),
    limit?,
  )
}

///|
fn search_query_pairs(query : SearchQuery) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = [("q", query.q)]
  if query.scope is Some(scope) {
    pairs.push(("scope", scope))
  }
  if query.all_words is Some(all_words) {
    pairs.push(("all_words", if all_words { "1" } else { "" }))
  }
  search_push_flag(pairs, "titles_only", query.titles_only)
  search_push_flag(pairs, "open_issues", query.open_issues)
  search_push_flag(pairs, "issues", query.issues)
  search_push_flag(pairs, "news", query.news)
  search_push_flag(pairs, "documents", query.documents)
  search_push_flag(pairs, "changesets", query.changesets)
  search_push_flag(pairs, "wiki_pages", query.wiki_pages)
  search_push_flag(pairs, "messages", query.messages)
  search_push_flag(pairs, "projects", query.projects)
  if query.attachments is Some(scope) {
    pairs.push(("attachments", scope.to_wire()))
  }
  pairs
}

///|
/// Unlike `all_words`, a flag is sent only when true, because Redmine enables a flag as soon as its parameter is present.
fn search_push_flag(
  pairs : Array[(String, String)],
  name : String,
  flag : Bool?,
) -> Unit {
  if flag is Some(true) {
    pairs.push((name, "1"))
  }
}
