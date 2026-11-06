///|
/// Failure of a Redmine call.
/// `Response` is a non-2xx answer carrying Redmine's own messages;
/// `Decode` is a 2xx answer whose body could not be read as the expected JSON;
/// `Transport` is any other failure without an HTTP status (connection, TLS, an unusable endpoint);
/// `InvalidArgument` is a request the SDK refused to send because an argument could not be sent as asked.
/// No case holds request headers, the request URL, or the API key.
///
/// ```mbt check
/// test {
///   fn describe(error : @redmine.RedmineError) -> String {
///     match error {
///       Response(status=404, ..) => "not found"
///       Response(status~, errors~) => "\{status}: \{errors.join(", ")}"
///       Decode(message~) | Transport(message~) | InvalidArgument(message~) =>
///         message
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
#derive(Debug, ToJson)
pub(all) suberror RedmineError {
  Response(status~ : Int32, errors~ : Array[String])
  Decode(message~ : String)
  Transport(message~ : String)
  InvalidArgument(message~ : String)
}

///|
pub extend RedmineError with @debug.Debug::{to_repr}

///|
pub extend RedmineError with ToJson::{to_json}
