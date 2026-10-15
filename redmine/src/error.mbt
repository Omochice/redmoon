///|
/// Failure of a Redmine call.
/// `Response` is a non-2xx answer carrying Redmine's own messages;
/// `Transport` is any failure without an HTTP status (connection, TLS, decoding).
/// Neither case holds request headers, the request URL, or the API key.
pub(all) suberror RedmineError {
  Response(status~ : Int32, errors~ : Array[String])
  Transport(message~ : String)
} derive(Debug, ToJson)

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

///|
pub extend RedmineError with @debug.Debug::{to_repr}

///|
pub extend RedmineError with ToJson::{to_json}
