///|
/// A Redmine plugin whose tools `serve --plugin` adds.
/// redmoon cannot tell which plugins an instance runs, so the user names them.
#derive(Eq, @debug.Debug)
pub(all) enum Plugin {
  IssueTemplates
  Agile
  AdditionalTags
}

///|
pub extend Plugin with Eq::{equal, not_equal}

///|
pub extend Plugin with @debug.Debug::{to_repr}

///|
priv struct KnownPlugin {
  name : String
  plugin : Plugin
  tool : (@redmine.Redmine, @tools.Mode) -> @mcp.Tool
}

///|
/// One row per plugin, so that adding a plugin touches this table and the enum
/// only; the order is the order the tools are registered in.
let known_plugins : Array[KnownPlugin] = [
  {
    name: "issue_templates",
    plugin: IssueTemplates,
    tool: (redmine, _) => @tools.issue_templates_tool(redmine),
  },
  {
    name: "agile",
    plugin: Agile,
    tool: (redmine, mode) => @tools.agile_tool(redmine, mode),
  },
  {
    name: "additional_tags",
    plugin: AdditionalTags,
    tool: (redmine, mode) => @tools.tags_tool(redmine, mode),
  },
]

///|
fn known_plugin_names() -> String {
  known_plugins.map(entry => entry.name).join(", ")
}

///|
/// Resolves the `--plugin` values, dropping repeats.
///
/// # Raises
/// `Message` naming the known plugins when a value is not one of them.
fn resolve_plugins(names : Array[String]) -> Array[Plugin] raise CliError {
  let plugins = []
  for name in names {
    guard known_plugins.search_by(entry => entry.name == name) is Some(index) else {
      raise Message(
        "unknown plugin `\{name}`; known plugins: \{known_plugin_names()}",
      )
    }
    let plugin = known_plugins[index].plugin
    if !plugins.contains(plugin) {
      plugins.push(plugin)
    }
  }
  plugins
}
