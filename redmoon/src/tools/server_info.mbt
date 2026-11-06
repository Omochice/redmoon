///|
/// `redmoon_info`: the server's own version and build, for bug reports.
pub fn server_info_tool(build~ : @build.BuildInfo? = @build.build) -> @mcp.Tool {
  @mcp.tool(
    name="redmoon_info",
    description=describe_tool([
      "Report this redmoon server's own release version and the git commit it was built from, for bug reports and debugging.",
      "This describes the MCP server itself, not a Redmine version; use `redmine_versions` for those.",
      "`build` is null when the server was built from source instead of a release build, and `dirty` says whether the build had uncommitted changes.",
    ]),
    input=@schema.keyed([("show", @schema.record([], _ => ()))]),
    handler=fn(_) {
      success({
        "version": Json(@build.version),
        "build": match build {
          Some(info) => Json(info)
          None => Json::null()
        },
      })
    },
  )
}
