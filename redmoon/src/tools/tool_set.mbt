///|
/// Builds one tool for a mode. The CLI holds an array of these so each tool
/// decides for itself which actions the mode removes.
pub type ToolFactory = (Mode) -> @mcp.Tool

///|
/// Builds every tool of `factories` for `mode`, keeping their order.
pub fn build_tools(
  factories : Array[ToolFactory],
  mode : Mode,
) -> Array[@mcp.Tool] {
  factories.map(factory => factory(mode))
}

///|
/// Wraps a tool that does not change with the mode.
pub fn always(tool : @mcp.Tool) -> ToolFactory {
  _ => tool
}
