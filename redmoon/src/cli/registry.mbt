///|
/// Every tool the server exposes for `mode`, bound to `redmine`.
pub fn registered_tools(
  redmine : @redmine.Redmine,
  mode : @tools.Mode,
) -> Array[@mcp.Tool] {
  [
    @tools.issues_tool(redmine, mode),
    @tools.wiki_pages_tool(redmine, mode),
    @tools.versions_tool(redmine, mode),
    @tools.relations_tool(redmine, mode),
    @tools.search_tool(redmine),
    @tools.time_entries_tool(redmine, mode),
    @tools.enumerations_tool(redmine),
    @tools.attachments_tool(redmine, @tools.LocalFile::new(), mode),
    @tools.server_info_tool(),
  ]
}

///|
/// The MCP server `serve` runs, kept apart from stdio so a test can drive it
/// over an in-memory pipe.
pub fn build_server(
  redmine : @redmine.Redmine,
  read_only : Bool,
) -> @mcp.Server {
  let mode : @tools.Mode = if read_only { Readonly } else { Full }
  @mcp.Server::new(
    name="redmoon",
    version=@build.version,
    tools=registered_tools(redmine, mode),
    on_invalid=@tools.on_invalid,
  )
}
