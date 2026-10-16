///|
/// A wiki page as listed for a project.
pub(all) struct WikiPageSummary {
  title : String
  version : Int32
  created_on : String
  updated_on : String
  parent : WikiParent?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend WikiPageSummary with @json.FromJson::{from_json}

///|
pub extend WikiPageSummary with ToJson::{to_json}

///|
pub extend WikiPageSummary with Eq::{equal, not_equal}

///|
pub extend WikiPageSummary with @debug.Debug::{to_repr}

///|
/// The parent of a wiki page, by title.
pub(all) struct WikiParent {
  title : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend WikiParent with @json.FromJson::{from_json}

///|
pub extend WikiParent with ToJson::{to_json}

///|
pub extend WikiParent with Eq::{equal, not_equal}

///|
pub extend WikiParent with @debug.Debug::{to_repr}

///|
/// A wiki page with its text, at one version.
pub(all) struct WikiPage {
  title : String
  version : Int32
  text : String
  author : IdName
  comments : String?
  created_on : String
  updated_on : String
  attachments : Array[WikiAttachment]?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend WikiPage with @json.FromJson::{from_json}

///|
pub extend WikiPage with ToJson::{to_json}

///|
pub extend WikiPage with Eq::{equal, not_equal}

///|
pub extend WikiPage with @debug.Debug::{to_repr}

///|
/// A file attached to a wiki page.
pub(all) struct WikiAttachment {
  id : Int32
  filename : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend WikiAttachment with @json.FromJson::{from_json}

///|
pub extend WikiAttachment with ToJson::{to_json}

///|
pub extend WikiAttachment with Eq::{equal, not_equal}

///|
pub extend WikiAttachment with @debug.Debug::{to_repr}

///|
/// Lists the wiki pages of `project`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::list_wiki_pages(
  self : Redmine,
  project : ProjectRef,
) -> Array[WikiPageSummary] raise RedmineError {
  let json = self.get(["projects", project.segment(), "wiki", "index.json"])
  decode_field(json, "wiki_pages")
}

///|
/// Shows a wiki page, at `version` when given and at the latest otherwise.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::show_wiki_page(
  self : Redmine,
  project : ProjectRef,
  title : String,
  version? : Int32,
) -> WikiPage raise RedmineError {
  let json = self.get(wiki_page_segments(project, title, version?))
  decode_field(json, "wiki_page")
}

///|
/// Creates the wiki page `title`, or replaces its text when it already exists.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::create_wiki_page(
  self : Redmine,
  project : ProjectRef,
  title : String,
  text : String,
  comments? : String,
  parent_title? : String,
) -> Unit raise RedmineError {
  let _ = self.send(
    Put,
    wiki_page_segments(project, title),
    body=wiki_page_body(text, comments?, parent_title?),
  )
}

///|
/// Replaces the text of the wiki page `title`.
/// With `version`, Redmine answers 409 when the page has changed since that version.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::update_wiki_page(
  self : Redmine,
  project : ProjectRef,
  title : String,
  text : String,
  comments? : String,
  version? : Int32,
  parent_title? : String,
) -> Unit raise RedmineError {
  let _ = self.send(
    Put,
    wiki_page_segments(project, title),
    body=wiki_page_body(text, comments?, version?, parent_title?),
  )
}

///|
/// Deletes the wiki page `title`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::delete_wiki_page(
  self : Redmine,
  project : ProjectRef,
  title : String,
) -> Unit raise RedmineError {
  let _ = self.send(Delete, wiki_page_segments(project, title))
}

///|
/// Mirrors `Wiki.titleize`: whitespace runs become one `_` and `,./?;|:` are dropped,
/// because Redmine stores the converted title and a differently spelled one is a different page.
fn wiki_title_segment(title : String) -> String {
  let out = StringBuilder()
  let mut in_space = false
  for c in title {
    if c is (' ' | '\t' | '\n' | '\r' | '\u000B' | '\u000C') {
      if !in_space {
        out.write_char('_')
        in_space = true
      }
    } else {
      in_space = false
      if !",./?;|:".contains_char(c) {
        out.write_char(c)
      }
    }
  }
  out.to_string()
}

///|
fn wiki_page_segments(
  project : ProjectRef,
  title : String,
  version? : Int32,
) -> Array[String] {
  let page = wiki_title_segment(title)
  match version {
    Some(version) =>
      [
        "projects",
        project.segment(),
        "wiki",
        page,
        version.to_string() + ".json",
      ]
    None => ["projects", project.segment(), "wiki", page + ".json"]
  }
}

///|
fn wiki_page_body(
  text : String,
  comments? : String,
  version? : Int32,
  parent_title? : String,
) -> Json {
  let page = present_members([
    ("text", Some(Json(text))),
    ("comments", comments.map(ToJson::to_json)),
    ("version", version.map(ToJson::to_json)),
    ("parent_title", parent_title.map(title => Json(wiki_title_segment(title)))),
  ])
  Json::object({ "wiki_page": page })
}
