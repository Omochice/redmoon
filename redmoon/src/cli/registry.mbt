///|
/// Every tool the server exposes for `mode`, bound to `redmine`.
pub fn registered_tools(
  redmine : @redmine.Redmine,
  mode : @tools.Mode,
) -> Array[@mcp.Tool] {
  @tools.build_tools(
    [
      mode => @tools.wiki_pages_tool(redmine, mode),
      mode => @tools.versions_tool(redmine, mode),
      mode => @tools.relations_tool(redmine, mode),
      @tools.always(@tools.search_tool(redmine)),
      mode => @tools.time_entries_tool(redmine, mode),
      @tools.always(@tools.enumerations_tool(redmine)),
      mode => @tools.attachments_tool(redmine, @tools.LocalFile::new(), mode),
      @tools.always(@tools.server_info_tool()),
    ],
    mode,
  )
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
    version=@build.VERSION,
    tools=registered_tools(redmine, mode),
    on_invalid=@tools.on_invalid,
  )
}
