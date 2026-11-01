///|
/// Opens every `Decode` message this package raises, so that a reader can tell an answer that arrived but could not be read
/// from a failure to reach Redmine at all.
const UNREADABLE : String = "The server answered, but the response could not be read"

///|
/// Decodes `json` into `T`, reporting a shape mismatch as `Decode` with the JSON path it occurred at.
pub fn[T : @json.FromJson] decode(json : Json) -> T raise @redmine.RedmineError {
  decode_at(json, "")
}

///|
/// Decodes `json[key]`, unwrapping the `{"<key>": ...}` envelope a plugin answers in.
/// Raises `Decode` when the envelope has no `key` or its value does not match `T`.
pub fn[T : @json.FromJson] decode_field(
  json : Json,
  key : String,
) -> T raise @redmine.RedmineError {
  guard json is Object(members) && members.get(key) is Some(value) else {
    raise @redmine.Decode(message="\{UNREADABLE}: it has no `\{key}`")
  }
  decode_at(value, "/\{key}")
}

///|
/// `JsonPath` has no public root constructor to extend with `key`, so the envelope's key is
/// prepended to the rendered path instead.
fn[T : @json.FromJson] decode_at(
  json : Json,
  prefix : String,
) -> T raise @redmine.RedmineError {
  @json.from_json(json) catch {
    JsonDecodeError((path, reason)) => {
      let at = "\{prefix}\{path}"
      let at = if at == "" { "/" } else { at }
      raise @redmine.Decode(message="\{UNREADABLE}: \{reason} at `\{at}`")
    }
  }
}
