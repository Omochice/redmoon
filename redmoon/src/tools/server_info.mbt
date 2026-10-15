///|
/// The commit a binary was built from.
pub(all) struct BuildInfo {
  commit : String
  dirty : Bool
} derive(ToJson)

///|
pub extend BuildInfo with ToJson::{to_json}

///|
/// The build info embedded in this binary, or `None` for a build from source.
pub fn current_build() -> BuildInfo? {
  match (@build.commit, @build.dirty) {
    (Some(commit), Some(dirty)) => Some({ commit, dirty, })
    _ => None
  }
}

///|
/// `redmoon_info`: the server's own version and build, for bug reports.
pub fn server_info_tool(build~ : BuildInfo? = current_build()) -> @mcp.Tool {
  @mcp.tool(
    name="redmoon_info",
    description="Report this redmoon server's own release version and the git commit it was built from, for bug reports and debugging.\nThis describes the MCP server itself, not a Redmine version; use `redmine_versions` for those.\n`build` is null when the server was built from source instead of a release build, and `dirty` says whether the build had uncommitted changes.\nPass the arguments under the single key `show`: `{\"show\": {}}`.",
    input=@schema.keyed([("show", @schema.object(()) |> @schema.Obj::done)]),
    handler=fn(_) {
      success({
        "version": Json(@build.VERSION),
        "build": match build {
          Some(info) => Json(info)
          None => Json::null()
        },
      })
    },
  )
}
