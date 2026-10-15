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
