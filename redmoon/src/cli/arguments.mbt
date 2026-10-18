///|
/// The subcommand the user asked for, with its options.
pub(all) enum Invocation {
  Serve(endpoint~ : String, read_only~ : Bool, plugins~ : Array[Plugin])
  Login(endpoint~ : String)
  Logout(endpoint~ : String)
  List
} derive(Eq, @debug.Debug)

///|
pub extend Invocation with Eq::{equal, not_equal}

///|
pub extend Invocation with @debug.Debug::{to_repr}

///|
fn endpoint_option() -> @argparse.OptionArg {
  @argparse.OptionArg("endpoint", about="Redmine endpoint URL.", required=true)
}

///|
fn command() -> @argparse.Command {
  @argparse.Command(
    "redmoon",
    about="MCP server for Redmine.",
    version=@build.version,
    subcommand_required=true,
    arg_required_else_help=true,
    subcommands=[
      @argparse.Command(
        "serve",
        about="Run the stdio MCP server for a Redmine endpoint.",
        options=[
          endpoint_option(),
          @argparse.OptionArg(
            "plugin",
            about="Add the tools of a Redmine plugin the instance runs; repeatable. Known: \{known_plugin_names()}.",
            action=Append,
          ),
        ],
        flags=[
          @argparse.FlagArg(
            "readonly",
            about="Expose only read actions; create, update, and delete are pruned.",
          ),
        ],
      ),
      @argparse.Command(
        "login",
        about="Store the API key for an endpoint in the OS keyring.",
        options=[endpoint_option()],
      ),
      @argparse.Command(
        "logout",
        about="Delete the stored API key for an endpoint from the OS keyring.",
        options=[endpoint_option()],
      ),
      @argparse.Command(
        "list",
        about="List endpoints that have a stored API key.",
      ),
    ],
  )
}

///|
/// Parses the process arguments, or `argv` when given.
///
/// # Raises
/// The parse error, whose text includes the usage; `--help` and `--version`
/// print and exit instead of returning.
pub fn parse_arguments(argv? : ArrayView[String]) -> Invocation raise {
  let matches = command().parse(argv?, env=Map([]))
  guard matches.subcommand is Some((name, sub)) else { fail("no subcommand") }
  let endpoint = sub.values.get("endpoint").map(values => values[0])
  match (name, endpoint) {
    ("serve", Some(endpoint)) =>
      Serve(
        endpoint~,
        read_only=sub.flags.get("readonly").unwrap_or(false),
        plugins=resolve_plugins(sub.values.get("plugin").unwrap_or([])),
      )
    ("login", Some(endpoint)) => Login(endpoint~)
    ("logout", Some(endpoint)) => Logout(endpoint~)
    ("list", _) => List
    _ => fail("unknown subcommand \{name}")
  }
}
