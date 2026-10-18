///|
/// A Redmine plugin whose tools `serve --plugin` adds.
/// redmoon cannot tell which plugins an instance runs, so the user names them.
pub(all) enum Plugin {
  IssueTemplates
} derive(Eq, @debug.Debug)

///|
pub extend Plugin with Eq::{equal, not_equal}

///|
pub extend Plugin with @debug.Debug::{to_repr}

///|
let known_plugins : Array[(String, Plugin)] = [
  ("issue_templates", IssueTemplates),
]

///|
fn known_plugin_names() -> String {
  known_plugins.map(entry => entry.0).join(", ")
}

///|
/// Resolves the `--plugin` values, dropping repeats.
///
/// # Raises
/// `Message` naming the known plugins when a value is not one of them.
fn resolve_plugins(names : Array[String]) -> Array[Plugin] raise CliError {
  let plugins = []
  for name in names {
    guard known_plugins.search_by(entry => entry.0 == name) is Some(index) else {
      raise Message(
        "unknown plugin `\{name}`; known plugins: \{known_plugin_names()}",
      )
    }
    let plugin = known_plugins[index].1
    if !plugins.contains(plugin) {
      plugins.push(plugin)
    }
  }
  plugins
}
