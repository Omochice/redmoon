///|
/// Reads the messages of a Redmine `{"errors": [...]}` body.
/// Returns an empty array when the body is empty, is not JSON, or has another shape.
pub fn errors_from_body(body : String) -> Array[String] {
  let json = @json.parse(body) catch { _ => return [] }
  guard json is { "errors": Array(items), .. } else { return [] }
  let messages = []
  for item in items {
    guard item is String(message) else { return [] }
    messages.push(message)
  }
  messages
}
