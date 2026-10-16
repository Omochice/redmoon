///|
/// A wiki page as listed for a project.
pub(all) struct PageSummary {
  title : String
  version : Int32
  created_on : String
  updated_on : String
  parent : Parent?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend PageSummary with @json.FromJson::{from_json}

///|
pub extend PageSummary with ToJson::{to_json}

///|
pub extend PageSummary with Eq::{equal, not_equal}

///|
pub extend PageSummary with @debug.Debug::{to_repr}

///|
/// The parent of a wiki page, by title.
pub(all) struct Parent {
  title : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Parent with @json.FromJson::{from_json}

///|
pub extend Parent with ToJson::{to_json}

///|
pub extend Parent with Eq::{equal, not_equal}

///|
pub extend Parent with @debug.Debug::{to_repr}

///|
/// A wiki page with its text, at one version.
pub(all) struct Page {
  title : String
  version : Int32
  text : String
  author : @redmine.IdName
  comments : String?
  created_on : String
  updated_on : String
  attachments : Array[Attachment]?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Page with @json.FromJson::{from_json}

///|
pub extend Page with ToJson::{to_json}

///|
pub extend Page with Eq::{equal, not_equal}

///|
pub extend Page with @debug.Debug::{to_repr}

///|
/// A file attached to a wiki page.
pub(all) struct Attachment {
  id : Int32
  filename : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Attachment with @json.FromJson::{from_json}

///|
pub extend Attachment with ToJson::{to_json}

///|
pub extend Attachment with Eq::{equal, not_equal}

///|
pub extend Attachment with @debug.Debug::{to_repr}

///|
/// Lists the wiki pages of `project`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn list(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
) -> Array[PageSummary] raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Get, ["projects", project.segment(), "wiki", "index.json"])
  @decode.decode_field(json, "wiki_pages")
}

///|
/// Shows a wiki page, at `version` when given and at the latest otherwise.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn show(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
  title : String,
  version? : Int32,
) -> Page raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Get, page_segments(project, title, version?))
  @decode.decode_field(json, "wiki_page")
}

///|
/// Creates the wiki page `title`, or replaces its text when it already exists.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn create(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
  title : String,
  text : String,
  comments? : String,
  parent_title? : String,
) -> Unit raise @redmine.RedmineError {
  ignore(
    redmine
    |> @redmine.send(
      Put,
      page_segments(project, title),
      body=page_body(text, comments?, parent_title?),
    ),
  )
}

///|
/// Replaces the text of the wiki page `title`.
/// With `version`, Redmine answers 409 when the page has changed since that version.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn update(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
  title : String,
  text : String,
  comments? : String,
  version? : Int32,
  parent_title? : String,
) -> Unit raise @redmine.RedmineError {
  ignore(
    redmine
    |> @redmine.send(
      Put,
      page_segments(project, title),
      body=page_body(text, comments?, version?, parent_title?),
    ),
  )
}

///|
/// Deletes the wiki page `title`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn delete(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
  title : String,
) -> Unit raise @redmine.RedmineError {
  ignore(redmine |> @redmine.send(Delete, page_segments(project, title)))
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
fn page_segments(
  project : @redmine.ProjectRef,
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
fn page_body(
  text : String,
  comments? : String,
  version? : Int32,
  parent_title? : String,
) -> Json {
  let page = @wire.present_members([
    ("text", Some(Json(text))),
    ("comments", comments.map(ToJson::to_json)),
    ("version", version.map(ToJson::to_json)),
    ("parent_title", parent_title.map(title => Json(wiki_title_segment(title)))),
  ])
  Json::object({ "wiki_page": page })
}
