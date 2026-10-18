///|
/// A template every project with the plugin enabled can use, unless it is limited to some projects.
pub(all) struct GlobalTemplate {
  id : Int32
  tracker_id : Int32
  title : String
  issue_title : String?
  description : String
  note : String?
  enabled : Bool
  created_on : String
  updated_on : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend GlobalTemplate with @json.FromJson::{from_json}

///|
pub extend GlobalTemplate with ToJson::{to_json}

///|
pub extend GlobalTemplate with Eq::{equal, not_equal}

///|
pub extend GlobalTemplate with @debug.Debug::{to_repr}

///|
/// A template that belongs to one project; `enabled_sharing` lets its subprojects inherit it.
pub(all) struct ProjectTemplate {
  id : Int32
  tracker_id : Int32
  title : String
  issue_title : String?
  description : String
  note : String?
  enabled : Bool
  is_default : Bool
  enabled_sharing : Bool
  position : Int32
  created_on : String
  updated_on : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend ProjectTemplate with @json.FromJson::{from_json}

///|
pub extend ProjectTemplate with ToJson::{to_json}

///|
pub extend ProjectTemplate with Eq::{equal, not_equal}

///|
pub extend ProjectTemplate with @debug.Debug::{to_repr}

///|
/// The templates a project can use: the global ones enabled for it, those its ancestors share, and its own.
pub(all) struct Templates {
  global : Array[GlobalTemplate]
  inherited : Array[ProjectTemplate]
  project : Array[ProjectTemplate]
} derive (
  FromJson(
    fields(
      global(rename="global_issue_templates"),
      inherited(rename="inherit_templates"),
      project(rename="issue_templates"),
    ),
  ),
  ToJson(
    fields(
      global(rename="global_issue_templates"),
      inherited(rename="inherit_templates"),
      project(rename="issue_templates"),
    ),
  ),
  Eq,
  Debug,
)

///|
pub extend Templates with @json.FromJson::{from_json}

///|
pub extend Templates with ToJson::{to_json}

///|
pub extend Templates with Eq::{equal, not_equal}

///|
pub extend Templates with @debug.Debug::{to_repr}

///|
/// Lists the issue templates `project` can use for issues of the tracker `tracker_id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure; an instance without the
/// redmine_issue_templates plugin answers 404.
///
/// ```mbt check
/// #skip("needs a live Redmine with the redmine_issue_templates plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let templates = redmine
///     |> @issue_templates.list(Identifier("demo"), tracker_id=1)
///   ignore(templates)
/// }
/// ```
pub async fn list(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
  tracker_id~ : Int32,
) -> Templates raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(
      Get,
      ["projects", project.segment(), "issue_templates", "list_templates.json"],
      query=[("issue_tracker_id", tracker_id.to_string())],
    )
  @decode.decode(json)
}
