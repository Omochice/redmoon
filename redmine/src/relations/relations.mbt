///|
/// The kind of link between two issues, spelled as Redmine spells it on the wire.
pub(all) enum Type {
  Relates
  Duplicates
  Duplicated
  Blocks
  Blocked
  Precedes
  Follows
  CopiedTo
  CopiedFrom
} derive(Eq, Debug)

///|
pub extend Type with Eq::{equal, not_equal}

///|
pub extend Type with @debug.Debug::{to_repr}

///|
fn Type::to_wire(self : Type) -> String {
  match self {
    Relates => "relates"
    Duplicates => "duplicates"
    Duplicated => "duplicated"
    Blocks => "blocks"
    Blocked => "blocked"
    Precedes => "precedes"
    Follows => "follows"
    CopiedTo => "copied_to"
    CopiedFrom => "copied_from"
  }
}

///|
fn Type::from_wire(wire : String) -> Type? {
  match wire {
    "relates" => Some(Relates)
    "duplicates" => Some(Duplicates)
    "duplicated" => Some(Duplicated)
    "blocks" => Some(Blocks)
    "blocked" => Some(Blocked)
    "precedes" => Some(Precedes)
    "follows" => Some(Follows)
    "copied_to" => Some(CopiedTo)
    "copied_from" => Some(CopiedFrom)
    _ => None
  }
}

///|
pub extend Type with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for Type with fn from_json(json, path) {
  guard json is String(wire) else {
    raise @json.JsonDecodeError((path, "Type::from_json: expected string"))
  }
  match Type::from_wire(wire) {
    Some(relation_type) => relation_type
    None =>
      raise @json.JsonDecodeError(
        (path, "Type::from_json: unknown relation type"),
      )
  }
}

///|

///|
pub extend Type with ToJson::{to_json}

///|
pub impl ToJson for Type with fn to_json(self) -> Json {
  ToJson::to_json(self.to_wire())
}

///|
/// An issue-to-issue relation as Redmine returns it.
pub(all) struct Relation {
  id : Int32
  issue_id : Int32
  issue_to_id : Int32
  relation_type : Type
  delay : Int32?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Relation with @json.FromJson::{from_json}

///|
pub extend Relation with ToJson::{to_json}

///|
pub extend Relation with Eq::{equal, not_equal}

///|
pub extend Relation with @debug.Debug::{to_repr}

///|
/// Lists every relation of the issue `issue_id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn list(
  redmine : @redmine.Redmine,
  issue_id : Int32,
) -> Array[Relation] raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Get, ["issues", issue_id.to_string(), "relations.json"])
  @decode.decode_field(json, "relations")
}

///|
/// Returns the relation with the given `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn show(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Relation raise @redmine.RedmineError {
  let json = redmine |> @redmine.send(Get, ["relations", "\{id}.json"])
  @decode.decode_field(json, "relation")
}

///|
/// Creates a relation from `issue_id` to `issue_to_id` and returns it.
/// Raises `RedmineError` on a non-2xx answer (e.g. the relation already exists) or a transport failure.
pub async fn create(
  redmine : @redmine.Redmine,
  issue_id : Int32,
  issue_to_id~ : Int32,
  relation_type~ : Type,
  delay? : Int32,
) -> Relation raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(
      Post,
      ["issues", issue_id.to_string(), "relations.json"],
      body=relation_body(issue_to_id, relation_type, delay),
    )
  @decode.decode_field(json, "relation")
}

///|
/// Deletes the relation with the given `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn delete(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Unit raise @redmine.RedmineError {
  ignore(redmine |> @redmine.send(Delete, ["relations", "\{id}.json"]))
}

///|
/// Builds the create body; `delay` is left out unless given so Redmine applies its own default.
fn relation_body(
  issue_to_id : Int32,
  relation_type : Type,
  delay : Int32?,
) -> Json {
  let relation = @wire.present_members([
    ("issue_to_id", Some(ToJson::to_json(issue_to_id))),
    ("relation_type", Some(ToJson::to_json(relation_type))),
    ("delay", delay.map(ToJson::to_json)),
  ])
  Json::object({ "relation": relation })
}
