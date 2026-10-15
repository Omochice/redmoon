///|
/// Tells the model how a call names its operation in the advertised schema.
pub let operation_key_hint : String = "Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`."

///|
/// The description of a CRUD resource tool. In `Readonly` mode the write verbs
/// are dropped so the description matches the pruned schema.
///
/// `resource` is the plural noun, e.g. `"issues"` or `"wiki pages"`.
/// `full_verbs` opens the `Full` summary for resources that lack some of the
/// four operations.
pub fn describe_crud_tool(
  resource : String,
  mode : Mode,
  full_verbs~ : String = "Create, read, update, and delete",
) -> String {
  let summary = match mode {
    Readonly => "List and show Redmine \{resource}"
    Full => "\{full_verbs} Redmine \{resource}"
  }
  "\{summary}. \{operation_key_hint}"
}
