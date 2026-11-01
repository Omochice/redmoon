///|
/// Rejects an object that carries none of `members`, advertised as `anyOf`.
/// A member counts as given when its key is present, as for `required`.
pub fn[T] Schema::require_any(
  self : Schema[T],
  members : Array[Member],
) -> Schema[T] {
  self.presence(members, at_least_one=true, at_most_one=false)
}

///|
/// Rejects an object that carries none or more than one of `members`,
/// advertised as `oneOf`.
/// A member counts as given when its key is present, as for `required`.
pub fn[T] Schema::require_one(
  self : Schema[T],
  members : Array[Member],
) -> Schema[T] {
  self.presence(members, at_least_one=true, at_most_one=true)
}

///|
/// Rejects an object that carries more than one of `members`, advertised as
/// `oneOf` with an alternative for carrying none.
/// A member counts as given when its key is present, as for `required`.
pub fn[T] Schema::allow_one(
  self : Schema[T],
  members : Array[Member],
) -> Schema[T] {
  self.presence(members, at_least_one=false, at_most_one=true)
}

///|
/// The combination is checked on the raw object before `self` decodes it,
/// because no member is wrong on its own, so a failure belongs to the object
/// and must not wait behind the members' own errors.
fn[T] Schema::presence(
  self : Schema[T],
  members : Array[Member],
  at_least_one~ : Bool,
  at_most_one~ : Bool,
) -> Schema[T] {
  let names = members.map(m => m.name)
  let keyword = if at_most_one { "oneOf" } else { "anyOf" }
  let each : Array[Json] = names.map(name => { "required": [name] })
  let alternatives = if at_least_one {
    each
  } else {
    [..each, { "not": { "anyOf": Json::array(each) } }]
  }
  {
    json: () => {
      with_constraint((self.json)(), keyword, Json::array(alternatives))
    },
    decode: (input, path) => {
      guard input is Object(fields) else { return (self.decode)(input, path) }
      let given = names.filter(name => fields.contains(name))
      if at_least_one && given.is_empty() {
        fail(path, "one of \{listing(names)} is required")
      }
      if at_most_one && given.length() > 1 {
        fail(path, "\{listing(given)} cannot be given together")
      }
      (self.decode)(input, path)
    },
  }
}

///|
fn listing(names : Array[String]) -> String {
  let quoted = names.map(name => "`\{name}`")
  match quoted.length() {
    0 | 1 => quoted.join("")
    n => quoted[:n - 1].join(", ") + " and " + quoted[n - 1]
  }
}

///|
/// Constraints already on the schema are moved with the new one into `allOf`
/// rather than overwritten, so a schema given several keeps them all.
fn with_constraint(base : Json, keyword : String, alternatives : Json) -> Json {
  guard base is Object(fields) else { base }
  let moved = ["anyOf", "oneOf"].filter(key => fields.contains(key))
  guard fields.contains("allOf") || !moved.is_empty() else {
    with_keywords(base, [(keyword, alternatives)])
  }
  let fields = fields.copy()
  let all_of = match fields.get("allOf") {
    Some(Array(all_of)) => all_of.copy()
    _ => []
  }
  for key in moved {
    all_of.push(Json::object(Map([(key, fields[key])])))
    fields.remove(key)
  }
  all_of.push(Json::object(Map([(keyword, alternatives)])))
  fields["allOf"] = Json::array(all_of)
  Json::object(fields)
}
