///|
fn with_keywords(base : Json, extra : Array[(String, Json)]) -> Json {
  guard base is Object(fields) else { base }
  let merged : Map[String, Json] = Map([])
  for key, value in fields {
    merged[key] = value
  }
  for entry in extra {
    merged[entry.0] = entry.1
  }
  Json::object(merged)
}
