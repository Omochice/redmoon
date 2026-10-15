///|
/// The kind of link between two issues, spelled as Redmine spells it on the wire.
pub(all) enum RelationType {
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
pub extend RelationType with Eq::{equal, not_equal}

///|
pub extend RelationType with @debug.Debug::{to_repr}

///|
fn RelationType::to_wire(self : RelationType) -> String {
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
fn RelationType::from_wire(wire : String) -> RelationType? {
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
pub extend RelationType with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for RelationType with fn from_json(json, path) {
  guard json is String(wire) else {
    raise @json.JsonDecodeError(
      (path, "RelationType::from_json: expected string"),
    )
  }
  match RelationType::from_wire(wire) {
    Some(relation_type) => relation_type
    None =>
      raise @json.JsonDecodeError(
        (path, "RelationType::from_json: unknown relation type"),
      )
  }
}

///|

///|
pub extend RelationType with ToJson::{to_json}

///|
pub impl ToJson for RelationType with fn to_json(self) -> Json {
  ToJson::to_json(self.to_wire())
}

///|
/// An issue-to-issue relation as Redmine returns it.
pub(all) struct Relation {
  id : Int32
  issue_id : Int32
  issue_to_id : Int32
  relation_type : RelationType
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
pub async fn Redmine::list_relations(
  self : Redmine,
  issue_id : Int32,
) -> Array[Relation] raise RedmineError {
  let json = self.get(["issues", issue_id.to_string(), "relations.json"])
  decode_field(json, "relations")
}

///|
/// Returns the relation with the given `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::show_relation(
  self : Redmine,
  id : Int32,
) -> Relation raise RedmineError {
  let json = self.get(["relations", "\{id}.json"])
  decode_field(json, "relation")
}

///|
/// Creates a relation from `issue_id` to `issue_to_id` and returns it.
/// Raises `RedmineError` on a non-2xx answer (e.g. the relation already exists) or a transport failure.
pub async fn Redmine::create_relation(
  self : Redmine,
  issue_id : Int32,
  issue_to_id~ : Int32,
  relation_type~ : RelationType,
  delay? : Int32,
) -> Relation raise RedmineError {
  let json = self.send(
    Post,
    ["issues", issue_id.to_string(), "relations.json"],
    body=relation_body(issue_to_id, relation_type, delay),
  )
  decode_field(json, "relation")
}

///|
/// Deletes the relation with the given `id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
pub async fn Redmine::delete_relation(
  self : Redmine,
  id : Int32,
) -> Unit raise RedmineError {
  ignore(self.send(Delete, ["relations", "\{id}.json"]))
}

///|
/// Builds the create body; `delay` is left out unless given so Redmine applies its own default.
fn relation_body(
  issue_to_id : Int32,
  relation_type : RelationType,
  delay : Int32?,
) -> Json {
  let fields : Map[String, Json] = {
    "issue_to_id": ToJson::to_json(issue_to_id),
    "relation_type": ToJson::to_json(relation_type),
  }
  if delay is Some(days) {
    fields["delay"] = ToJson::to_json(days)
  }
  Json::object({ "relation": Json::object(fields) })
}
