///|
/// Decodes `json` into `T`, reporting a shape mismatch as `Transport`.
pub fn[T : @json.FromJson] decode(json : Json) -> T raise @redmine.RedmineError {
  @json.from_json(json) catch {
    error =>
      raise @redmine.Transport(message="unexpected response shape: \{error}")
  }
}

///|
/// Decodes `json[key]`, unwrapping Redmine's `{"<key>": ...}` envelope.
pub fn[T : @json.FromJson] decode_field(
  json : Json,
  key : String,
) -> T raise @redmine.RedmineError {
  guard json is Object(members) && members.get(key) is Some(value) else {
    raise @redmine.Transport(message="response has no `\{key}`")
  }
  decode(value)
}
