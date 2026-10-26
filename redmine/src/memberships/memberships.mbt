///|
/// The user or group a membership grants roles to.
/// `AnonymousGroup` and `NonMemberGroup` are Redmine's built-in groups, which stand for every anonymous visitor and every logged-in non-member.
pub(all) enum Principal {
  User(@redmine.IdName)
  Group(@redmine.IdName)
  AnonymousGroup(@redmine.IdName)
  NonMemberGroup(@redmine.IdName)
} derive(Eq, Debug)

///|
pub extend Principal with Eq::{equal, not_equal}

///|
pub extend Principal with @debug.Debug::{to_repr}

///|
/// The member Redmine names after the principal's class.
fn Principal::key(self : Principal) -> String {
  match self {
    User(_) => "user"
    Group(_) => "group"
    AnonymousGroup(_) => "group_anonymous"
    NonMemberGroup(_) => "group_non_member"
  }
}

///|
fn Principal::id_name(self : Principal) -> @redmine.IdName {
  match self {
    User(id_name)
    | Group(id_name)
    | AnonymousGroup(id_name)
    | NonMemberGroup(id_name) => id_name
  }
}

///|
/// A role held through a membership; `inherited` is true for a role a user holds through one of its groups.
pub(all) struct Role {
  id : Int32
  name : String
  inherited : Bool
} derive(Eq, Debug)

///|
pub extend Role with Eq::{equal, not_equal}

///|
pub extend Role with @debug.Debug::{to_repr}

///|
pub extend Role with @json.FromJson::{from_json}

///|
pub extend Role with ToJson::{to_json}

///|
/// Redmine writes `inherited` only when it is true.
pub impl @json.FromJson for Role with fn from_json(json, path) {
  guard json is Object(members) else {
    raise @json.JsonDecodeError((path, "Role::from_json: expected object"))
  }
  {
    id: field(members, "id", path),
    name: field(members, "name", path),
    inherited: match members.get("inherited") {
      Some(value) => @json.from_json(value, path=path.add_key("inherited"))
      None => false
    },
  }
}

///|
pub impl ToJson for Role with fn to_json(self) {
  { "id": self.id, "name": self.name, "inherited": self.inherited }
}

///|
/// A project membership: the roles one principal holds in one project.
pub(all) struct Membership {
  id : Int32
  project : @redmine.IdName
  principal : Principal
  roles : Array[Role]
} derive(Eq, Debug)

///|
pub extend Membership with Eq::{equal, not_equal}

///|
pub extend Membership with @debug.Debug::{to_repr}

///|
pub extend Membership with @json.FromJson::{from_json}

///|
pub extend Membership with ToJson::{to_json}

///|
pub impl @json.FromJson for Membership with fn from_json(json, path) {
  guard json is Object(members) else {
    raise @json.JsonDecodeError(
      (path, "Membership::from_json: expected object"),
    )
  }
  {
    id: field(members, "id", path),
    project: field(members, "project", path),
    principal: principal_of(members, path),
    roles: field(members, "roles", path),
  }
}

///|
/// The principal is written under its own key rather than a shared `principal` member, so that the output keeps the shape of Redmine's response.
pub impl ToJson for Membership with fn to_json(self) {
  let object : Map[String, Json] = Map([
    ("id", Json(self.id)),
    ("project", Json(self.project)),
    (self.principal.key(), Json(self.principal.id_name())),
    ("roles", Json(self.roles)),
  ])
  Json::object(object)
}

///|
fn principal_of(
  members : Map[String, Json],
  path : @json.JsonPath,
) -> Principal raise @json.JsonDecodeError {
  match members {
    { "user": _, .. } => User(field(members, "user", path))
    { "group": _, .. } => Group(field(members, "group", path))
    { "group_anonymous": _, .. } =>
      AnonymousGroup(field(members, "group_anonymous", path))
    { "group_non_member": _, .. } =>
      NonMemberGroup(field(members, "group_non_member", path))
    _ =>
      raise @json.JsonDecodeError(
        (path, "Membership::from_json: no user or group"),
      )
  }
}

///|
fn[T : @json.FromJson] field(
  members : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T raise @json.JsonDecodeError {
  guard members.get(key) is Some(value) else {
    raise @json.JsonDecodeError((path, "missing field `\{key}`"))
  }
  @json.from_json(value, path=path.add_key(key))
}

///|
/// Lists the memberships of `project`, following every page unless `limit` caps the count.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let memberships = redmine |> @memberships.list(Identifier("demo"))
///   ignore(memberships)
/// }
/// ```
pub async fn list(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
  limit? : Int32,
) -> Array[Membership] raise @redmine.RedmineError {
  @paging.list_all(
    redmine,
    ["projects", project.segment(), "memberships.json"],
    key="memberships",
    limit?,
  )
}
