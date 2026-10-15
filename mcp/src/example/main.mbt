///|
async fn main {
  let text = @schema.required("text", @schema.string())
  let echo = @mcp.tool(
    name="echo",
    description="Returns the given text",
    input=@schema.record([text.as_member()], v => v.get(text)),
    handler=fn(text) { @mcp.ToolResult::text(text) },
  )
  @mcp.Server::new(name="mcp-example", version="0.1.0", tools=[echo]).serve_stdio()
}
