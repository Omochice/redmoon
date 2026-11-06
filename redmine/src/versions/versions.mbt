///|
/// Whether issues can still be assigned to a version.
#derive(Eq, Debug)
pub(all) enum Status {
  Open
  Locked
  Closed
}

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
  guard json is String(wire) else {
    raise @json.JsonDecodeError((path, "Status::from_json: expected string"))
  }
  match wire {
    "open" => Open
    "locked" => Locked
    "closed" => Closed
    _ =>
      raise @json.JsonDecodeError(
        (path, "Status::from_json: unknown version status `\{wire}`"),
      )
  }
}

///|
/// Which projects can use a version.
#derive(Eq, Debug)
pub(all) enum Sharing {
  None
  Descendants
  Hierarchy
  Tree
  System
}

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
  guard json is String(wire) else {
    raise @json.JsonDecodeError((path, "Sharing::from_json: expected string"))
  }
  match wire {
    "none" => None
    "descendants" => Descendants
    "hierarchy" => Hierarchy
    "tree" => Tree
    "system" => System
    _ =>
      raise @json.JsonDecodeError(
        (path, "Sharing::from_json: unknown version sharing `\{wire}`"),
      )
  }
}

///|
/// A project version (milestone).
#derive(FromJson, ToJson, Eq, Debug)
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
}

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
#derive(Eq, Debug)
pub struct Create {
  name : String
  description : String?
  status : Status?
  due_date : String?
  sharing : Sharing?
  wiki_page_title : String?
}

///|
pub extend Create with Eq::{equal, not_equal}

///|
pub extend Create with @debug.Debug::{to_repr}

///|
/// The attributes of a version to create; only `name` must be given.
///
/// ```mbt check
/// test {
///   let create = @versions.Create::new(
///     name="1.0",
///     status=Open,
///     due_date="2026-12-31",
///   )
///   assert_eq(create.status, Some(@versions.Status::Open))
///   assert_true(create.description is None)
/// }
/// ```
pub fn Create::new(
  name~ : String,
  description? : String,
  status? : Status,
  due_date? : String,
  sharing? : Sharing,
  wiki_page_title? : String,
) -> Create {
  { name, description, status, due_date, sharing, wiki_page_title, }
}

///|
/// Attributes of a version to change; fields left `None` are not sent.
/// `Clear` empties the description, the due date, or the wiki page title; `due_date` is `YYYY-MM-DD`.
#derive(Eq, Debug)
pub struct Update {
  name : String?
  description : @redmine.Clearable[String]?
  status : Status?
  due_date : @redmine.Clearable[String]?
  sharing : Sharing?
  wiki_page_title : @redmine.Clearable[String]?
}

///|
pub extend Update with Eq::{equal, not_equal}

///|
pub extend Update with @debug.Debug::{to_repr}

///|
/// The attributes of a version to change; only the fields given are touched.
///
/// ```mbt check
/// test {
///   let update = @versions.Update::new(status=Closed, due_date=Clear)
///   assert_eq(update.status, Some(@versions.Status::Closed))
///   assert_eq(update.due_date, Some(@redmine.Clearable::Clear))
///   assert_true(update.name is None)
/// }
/// ```
pub fn Update::new(
  name? : String,
  description? : @redmine.Clearable[String],
  status? : Status,
  due_date? : @redmine.Clearable[String],
  sharing? : Sharing,
  wiki_page_title? : @redmine.Clearable[String],
) -> Update {
  { name, description, status, due_date, sharing, wiki_page_title, }
}

///|
/// Lists the versions of `project`; Redmine answers them all in one response.
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
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
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
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
  let json = redmine |> @redmine.send(Get, ["versions", "\{id}.json"])
  @decode.decode_field(json, "version")
}

///|
/// Creates a version in `project` and returns it.
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let version = redmine
///     |> @versions.create(
///       Identifier("demo"),
///       @versions.Create::new(name="1.0", due_date="2026-12-31"),
///     )
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
      body=attributes.to_body(),
    )
  @decode.decode_field(json, "version")
}

///|
/// Changes the version `id`.
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine |> @versions.update(3, @versions.Update::new(status=Closed))
/// }
/// ```
pub async fn update(
  redmine : @redmine.Redmine,
  id : Int32,
  attributes : Update,
) -> Unit raise @redmine.RedmineError {
  ignore(
    redmine
    |> @redmine.send(Put, ["versions", "\{id}.json"], body=attributes.to_body()),
  )
}

///|
/// Deletes the version `id`.
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
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
  ignore(redmine |> @redmine.send(Delete, ["versions", "\{id}.json"]))
}

///|
fn Create::to_body(self : Create) -> Json {
  let version = @wire.present_members([
    ("name", Some(Json(self.name))),
    ("description", self.description.map(ToJson::to_json)),
    ("status", self.status.map(ToJson::to_json)),
    ("due_date", self.due_date.map(ToJson::to_json)),
    ("sharing", self.sharing.map(ToJson::to_json)),
    ("wiki_page_title", self.wiki_page_title.map(ToJson::to_json)),
  ])
  Json::object({ "version": version })
}

///|
fn Update::to_body(self : Update) -> Json {
  let version = @wire.present_members([
    ("name", self.name.map(ToJson::to_json)),
    (
      "description",
      @redmine.Clearable::to_member(self.description, set=ToJson::to_json),
    ),
    ("status", self.status.map(ToJson::to_json)),
    (
      "due_date",
      @redmine.Clearable::to_member(self.due_date, set=ToJson::to_json),
    ),
    ("sharing", self.sharing.map(ToJson::to_json)),
    (
      "wiki_page_title",
      @redmine.Clearable::to_member(self.wiki_page_title, set=ToJson::to_json),
    ),
  ])
  Json::object({ "version": version })
}
