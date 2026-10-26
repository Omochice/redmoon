///|
/// Every tool the server exposes for `mode` and the enabled `plugins`, bound to `redmine`.
pub fn registered_tools(
  redmine : @redmine.Redmine,
  mode : @tools.Mode,
  plugins : Array[Plugin],
) -> Array[@mcp.Tool] {
  let tools = [
    @tools.issues_tool(redmine, mode),
    @tools.wiki_pages_tool(redmine, mode),
    @tools.versions_tool(redmine, mode),
    @tools.relations_tool(redmine, mode),
    @tools.search_tool(redmine),
    @tools.time_entries_tool(redmine, mode),
    @tools.enumerations_tool(redmine),
    @tools.memberships_tool(redmine),
    @tools.attachments_tool(redmine, @tools.LocalFile::new(), mode),
    @tools.server_info_tool(),
  ]
  if plugins.contains(IssueTemplates) {
    tools.push(@tools.issue_templates_tool(redmine))
  }
  tools
}

///|
/// The MCP server `serve` runs, kept apart from stdio so a test can drive it
/// over an in-memory pipe.
pub fn build_server(
  redmine : @redmine.Redmine,
  read_only : Bool,
  plugins : Array[Plugin],
) -> @mcp.Server {
  let mode : @tools.Mode = if read_only { Readonly } else { Full }
  @mcp.Server::new(
    name="redmoon",
    version=@build.version,
    tools=registered_tools(redmine, mode, plugins),
    on_invalid=@tools.on_invalid,
  )
}
