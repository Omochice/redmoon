///|
/// Compact JSON, since a model reads the payload rather than a human.
pub fn[T : ToJson] success(value : T) -> @mcp.ToolResult {
  @mcp.ToolResult::text(value.to_json().stringify())
}

///|
/// The success of an operation with nothing to report.
pub fn success_ok() -> @mcp.ToolResult {
  @mcp.ToolResult::text("{\"ok\":true}")
}

///|
/// A failure holding `{"status": ..., "errors": [...]}`, the only failure
/// shape a model sees.
pub fn failure(status : Int32, errors : Array[String]) -> @mcp.ToolResult {
  let payload : Json = { "status": Json(status), "errors": Json(errors) }
  @mcp.ToolResult::error(payload.stringify())
}

///|
/// A failure that has no HTTP status, such as invalid arguments or a local
/// file error; the status is 0.
pub fn local_failure(errors : Array[String]) -> @mcp.ToolResult {
  failure(0, errors)
}

///|
/// Maps a Redmine failure to the failure payload: a response keeps its status
/// and messages, anything else reports status 0 with its message.
pub fn failure_of(error : @redmine.RedmineError) -> @mcp.ToolResult {
  match error {
    Response(status~, errors~) => failure(status, errors)
    Transport(message~) => local_failure([message])
  }
}

///|
/// Never raises: a failed `call` becomes the failure payload instead.
pub async fn[T : ToJson] respond(
  call : async () -> T raise @redmine.RedmineError,
) -> @mcp.ToolResult {
  let value = call() catch { error => return failure_of(error) }
  success(value)
}

///|
/// Like `respond`, answering `{"ok":true}` for a call that returns nothing.
pub async fn respond_ok(
  call : async () -> Unit raise @redmine.RedmineError,
) -> @mcp.ToolResult {
  call() catch {
    error => return failure_of(error)
  }
  success_ok()
}
