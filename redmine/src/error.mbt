///|
/// Failure of a Redmine call.
/// `Response` is a non-2xx answer carrying Redmine's own messages;
/// `Transport` is any failure without an HTTP status (connection, TLS, decoding).
/// Neither case holds request headers, the request URL, or the API key.
///
/// ```mbt check
/// test {
///   fn describe(error : @redmine.RedmineError) -> String {
///     match error {
///       Response(status=404, ..) => "not found"
///       Response(status~, errors~) => "\{status}: \{errors.join(", ")}"
///       Transport(message~) => message
///     }
///   }
///
///   inspect(describe(Response(status=404, errors=[])), content="not found")
///   inspect(
///     describe(Response(status=422, errors=["Subject cannot be blank"])),
///     content="422: Subject cannot be blank",
///   )
/// }
/// ```
pub(all) suberror RedmineError {
  Response(status~ : Int32, errors~ : Array[String])
  Transport(message~ : String)
} derive(Debug, ToJson)

///|
pub extend RedmineError with @debug.Debug::{to_repr}

///|
pub extend RedmineError with ToJson::{to_json}
