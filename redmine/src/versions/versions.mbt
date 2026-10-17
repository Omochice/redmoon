///|
/// Whether issues can still be assigned to a version.
pub(all) enum Status {
  Open
  Locked
  Closed
} derive(Eq, Debug)

///|
pub extend Status with Eq::{equal, not_equal}

///|
pub extend Status with ToJson::{to_json}

///|
pub extend Status with @json.FromJson::{from_json}

///|
pub extend Status with @debug.Debug::{to_repr}

///|
pub impl ToJson for Status with fn to_json(self) -> Json {
  match self {
    Open => "open"
    Locked => "locked"
    Closed => "closed"
  }
}

///|
pub impl @json.FromJson for Status with fn from_json(json, path) {
  match json {
    "open" => Open
    "locked" => Locked
    "closed" => Closed
    _ => raise @json.JsonDecodeError((path, "unknown version status"))
  }
}

///|
/// Which projects can use a version.
pub(all) enum Sharing {
  None
  Descendants
  Hierarchy
  Tree
  System
} derive(Eq, Debug)

///|
pub extend Sharing with Eq::{equal, not_equal}

///|
pub extend Sharing with ToJson::{to_json}

///|
pub extend Sharing with @json.FromJson::{from_json}

///|
pub extend Sharing with @debug.Debug::{to_repr}

///|
pub impl ToJson for Sharing with fn to_json(self) -> Json {
  match self {
    None => "none"
    Descendants => "descendants"
    Hierarchy => "hierarchy"
    Tree => "tree"
    System => "system"
  }
}

///|
pub impl @json.FromJson for Sharing with fn from_json(json, path) {
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
  project : @redmine.IdName
  name : String
  description : String?
  status : Status
  due_date : String?
  sharing : Sharing
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
///
/// ```mbt check
/// test {
///   let create : @versions.Create = {
///     name: "1.0",
///     description: None,
///     status: Some(Open),
///     due_date: Some("2026-12-31"),
///     sharing: None,
///     wiki_page_title: None,
///   }
///   assert_eq(create.status, Some(@versions.Status::Open))
/// }
/// ```
pub(all) struct Create {
  name : String
  description : String?
  status : Status?
  due_date : String?
  sharing : Sharing?
  wiki_page_title : String?
} derive(Eq, Debug)

///|
pub extend Create with Eq::{equal, not_equal}

///|
pub extend Create with @debug.Debug::{to_repr}

///|
/// Attributes of a version to change; fields left `None` are not sent.
pub(all) struct Update {
  name : String?
  description : String?
  status : Status?
  due_date : String?
  sharing : Sharing?
  wiki_page_title : String?
} derive(Eq, Debug)

///|
pub extend Update with Eq::{equal, not_equal}

///|
pub extend Update with @debug.Debug::{to_repr}

///|
/// Lists the versions of `project`; Redmine answers them all in one response.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let versions = redmine |> @versions.list(Identifier("demo"))
///   ignore(versions)
/// }
/// ```
pub async fn list(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
) -> Array[Version] raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Get, ["projects", project.segment(), "versions.json"])
  @decode.decode_field(json, "versions")
}

///|
/// Shows the version `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let version = redmine |> @versions.show(3)
///   ignore(version)
/// }
/// ```
pub async fn show(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Version raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Get, ["versions", id.to_string() + ".json"])
  @decode.decode_field(json, "version")
}

///|
/// Creates a version in `project` and returns it.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let version = redmine
///     |> @versions.create(Identifier("demo"), {
///       name: "1.0",
///       description: None,
///       status: None,
///       due_date: Some("2026-12-31"),
///       sharing: None,
///       wiki_page_title: None,
///     })
///   ignore(version)
/// }
/// ```
pub async fn create(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
  attributes : Create,
) -> Version raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(
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
  @decode.decode_field(json, "version")
}

///|
/// Changes the version `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine
///   |> @versions.update(3, {
///     name: None,
///     description: None,
///     status: Some(Closed),
///     due_date: None,
///     sharing: None,
///     wiki_page_title: None,
///   })
/// }
/// ```
pub async fn update(
  redmine : @redmine.Redmine,
  id : Int32,
  attributes : Update,
) -> Unit raise @redmine.RedmineError {
  ignore(
    redmine
    |> @redmine.send(
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
    ),
  )
}

///|
/// Deletes the version `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine |> @versions.delete(3)
/// }
/// ```
pub async fn delete(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Unit raise @redmine.RedmineError {
  ignore(
    redmine |> @redmine.send(Delete, ["versions", id.to_string() + ".json"]),
  )
}

///|
fn version_body(
  name : String?,
  description : String?,
  status : Status?,
  due_date : String?,
  sharing : Sharing?,
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
