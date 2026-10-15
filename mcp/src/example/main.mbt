///|
async fn main {
  let echo = @mcp.tool(
    name="echo",
    description="Returns the given text",
    input=@schema.object(text => text)
      |> @schema.field("text", @schema.string())
      |> @schema.Obj::done,
    handler=fn(text) { @mcp.ToolResult::text(text) },
  )
  @mcp.Server::new(name="mcp-example", version="0.1.0", tools=[echo]).serve_stdio()
}
