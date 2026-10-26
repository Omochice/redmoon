///|
/// Removes every object member whose value is `null`, recursively.
/// Array elements are kept as they are, including `null` elements.
pub fn strip_nulls(json : Json) -> Json {
  match json {
    Object(members) => {
      let kept : Map[String, Json] = Map([])
      for key, value in members {
        guard value is Null else { kept[key] = strip_nulls(value) }
      }
      Json::object(kept)
    }
    Array(items) => Json::array(items.map(strip_nulls))
    other => other
  }
}

///|
/// Builds a JSON object from the members that are present, in the given order.
pub fn present_members(members : Array[(String, Json?)]) -> Json {
  let object : Map[String, Json] = Map([])
  for entry in members {
    if entry.1 is Some(value) {
      object[entry.0] = value
    }
  }
  Json::object(object)
}
