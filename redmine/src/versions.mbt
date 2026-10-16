///|
/// Whether issues can still be assigned to a version.
pub(all) enum VersionStatus {
  Open
  Locked
  Closed
} derive(Eq, Debug)

///|
pub extend VersionStatus with Eq::{equal, not_equal}

///|
pub extend VersionStatus with ToJson::{to_json}

///|
pub extend VersionStatus with @json.FromJson::{from_json}

///|
pub extend VersionStatus with @debug.Debug::{to_repr}

///|
pub impl ToJson for VersionStatus with fn to_json(self) -> Json {
  match self {
    Open => "open"
    Locked => "locked"
    Closed => "closed"
  }
}

///|
pub impl @json.FromJson for VersionStatus with fn from_json(json, path) {
  match json {
    "open" => Open
    "locked" => Locked
    "closed" => Closed
    _ => raise @json.JsonDecodeError((path, "unknown version status"))
  }
}

///|
/// Which projects can use a version.
pub(all) enum VersionSharing {
  None
  Descendants
  Hierarchy
  Tree
  System
} derive(Eq, Debug)

///|
pub extend VersionSharing with Eq::{equal, not_equal}

///|
pub extend VersionSharing with ToJson::{to_json}

///|
pub extend VersionSharing with @json.FromJson::{from_json}

///|
pub extend VersionSharing with @debug.Debug::{to_repr}

///|
pub impl ToJson for VersionSharing with fn to_json(self) -> Json {
  match self {
    None => "none"
    Descendants => "descendants"
    Hierarchy => "hierarchy"
    Tree => "tree"
    System => "system"
  }
}

///|
pub impl @json.FromJson for VersionSharing with fn from_json(json, path) {
  match json {
    "none" => None
    "descendants" => Descendants
    "hierarchy" => Hierarchy
    "tree" => Tree
    "system" => System
    _ => raise @json.JsonDecodeError((path, "unknown version sharing"))
  }
}

///|
/// A project version (milestone).
pub(all) struct Version {
  id : Int32
  project : IdName
  name : String
  description : String?
  status : VersionStatus
  due_date : String?
  sharing : VersionSharing
  wiki_page_title : String?
  created_on : String
  updated_on : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Version with @json.FromJson::{from_json}

///|
pub extend Version with ToJson::{to_json}

///|
pub extend Version with Eq::{equal, not_equal}

///|
pub extend Version with @debug.Debug::{to_repr}

///|
/// Attributes of a version to create; `due_date` is `YYYY-MM-DD`.
pub(all) struct VersionCreate {
  name : String
  description : String?
  status : VersionStatus?
  due_date : String?
  sharing : VersionSharing?
  wiki_page_title : String?
} derive(Eq, Debug)

///|
pub extend VersionCreate with Eq::{equal, not_equal}

///|
pub extend VersionCreate with @debug.Debug::{to_repr}

///|
/// Attributes of a version to change; fields left `None` are not sent.
pub(all) struct VersionUpdate {
  name : String?
  description : String?
  status : VersionStatus?
  due_date : String?
  sharing : VersionSharing?
  wiki_page_title : String?
} derive(Eq, Debug)

///|
pub extend VersionUpdate with Eq::{equal, not_equal}

///|
pub extend VersionUpdate with @debug.Debug::{to_repr}

///|
/// Lists the versions of `project`; Redmine answers them all in one response.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::list_versions(
  self : Redmine,
  project : ProjectRef,
) -> Array[Version] raise RedmineError {
  let json = self.get(["projects", project.segment(), "versions.json"])
  decode_field(json, "versions")
}

///|
/// Shows the version `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::show_version(
  self : Redmine,
  id : Int32,
) -> Version raise RedmineError {
  let json = self.get(["versions", id.to_string() + ".json"])
  decode_field(json, "version")
}

///|
/// Creates a version in `project` and returns it.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::create_version(
  self : Redmine,
  project : ProjectRef,
  attributes : VersionCreate,
) -> Version raise RedmineError {
  let json = self.send(
    Post,
    ["projects", project.segment(), "versions.json"],
    body=version_body(
      Some(attributes.name),
      attributes.description,
      attributes.status,
      attributes.due_date,
      attributes.sharing,
      attributes.wiki_page_title,
    ),
  )
  decode_field(json, "version")
}

///|
/// Changes the version `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::update_version(
  self : Redmine,
  id : Int32,
  attributes : VersionUpdate,
) -> Unit raise RedmineError {
  let _ = self.send(
    Put,
    ["versions", id.to_string() + ".json"],
    body=version_body(
      attributes.name,
      attributes.description,
      attributes.status,
      attributes.due_date,
      attributes.sharing,
      attributes.wiki_page_title,
    ),
  )
}

///|
/// Deletes the version `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::delete_version(
  self : Redmine,
  id : Int32,
) -> Unit raise RedmineError {
  let _ = self.send(Delete, ["versions", id.to_string() + ".json"])
}

///|
fn version_body(
  name : String?,
  description : String?,
  status : VersionStatus?,
  due_date : String?,
  sharing : VersionSharing?,
  wiki_page_title : String?,
) -> Json {
  let version = @wire.present_members([
    ("name", name.map(ToJson::to_json)),
    ("description", description.map(ToJson::to_json)),
    ("status", status.map(ToJson::to_json)),
    ("due_date", due_date.map(ToJson::to_json)),
    ("sharing", sharing.map(ToJson::to_json)),
    ("wiki_page_title", wiki_page_title.map(ToJson::to_json)),
  ])
  Json::object({ "version": version })
}
