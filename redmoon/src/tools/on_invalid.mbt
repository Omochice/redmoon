///|
/// The `on_invalid` of `@mcp.Server::new`: one `invalid arguments: ...` error
/// per failed value, with the action in its path.
pub fn on_invalid(error : @schema.SchemaError) -> @mcp.ToolResult {
  local_failure(error.messages().map(m => "invalid arguments: \{m}"))
}
