///|
/// Keywords that annotate a schema rather than constrain it, so a later one
/// supersedes an earlier one instead of being conjoined with it.
let annotation_keywords : Array[String] = ["description", "default"]

///|
/// Keywords that each hold a list of alternatives; a second one is moved with
/// the first under `allOf` so the two lists are not read as one.
let alternative_keywords : Array[String] = ["anyOf", "oneOf"]

///|
fn bounded(
  type_ : String,
  lower : (String, Json?),
  upper : (String, Json?),
) -> Json {
  let entries : Array[(String, Json)] = [("type", Json(type_))]
  for bound in [lower, upper] {
    if bound.1 is Some(value) {
      entries.push((bound.0, value))
    }
  }
  Json::object(Map::from_array(entries))
}

///|
/// Adds `keyword` to `base`.
/// An annotation replaces an earlier one, while a constraint already present with another value, or one added next to a list of alternatives, is conjoined under `allOf` rather than overwritten, so a schema given several constraints keeps them all.
fn compose(base : Json, keyword : String, value : Json) -> Json {
  guard base is Object(fields) else { base }
  guard fields.get(keyword) != Some(value) else { base }
  let fields = fields.copy()
  let moved = alternative_keywords.filter(key => fields.contains(key))
  if fields.contains(keyword) && !moved.contains(keyword) {
    moved.push(keyword)
  }
  guard !annotation_keywords.contains(keyword) &&
    (fields.contains("allOf") || !moved.is_empty()) else {
    fields[keyword] = value
    Json::object(fields)
  }
  let all_of = match fields.get("allOf") {
    Some(Array(all_of)) => all_of.copy()
    _ => []
  }
  for key in moved {
    all_of.push(Json::object(Map([(key, fields[key])])))
    fields.remove(key)
  }
  all_of.push(Json::object(Map([(keyword, value)])))
  fields["allOf"] = Json::array(all_of)
  Json::object(fields)
}
