///|
priv enum RelationAction {
  List(Int32)
  Show(Int32)
}

///|
fn relation_input() -> @schema.Schema[RelationAction] {
  let entries : Array[(String, @schema.Schema[RelationAction])] = [
    (
      "list",
      @schema.object(issue_id => List(issue_id))
      |> @schema.field("issue_id", record_id())
      |> @schema.Obj::done,
    ),
    (
      "show",
      @schema.object(id => Show(id))
      |> @schema.field("id", record_id())
      |> @schema.Obj::done,
    ),
  ]
  @schema.keyed(entries)
}

///|
/// `redmine_issue_relations`: the links between issues.
pub fn relations_tool(port : &RelationPort, mode : Mode) -> @mcp.Tool {
  let summary = match mode {
    Readonly => "List and show Redmine issue relations"
    Full => "Create, read, and delete Redmine issue relations"
  }
  @mcp.tool(
    name="redmine_issue_relations",
    description="\{summary}. \{operation_key_hint}",
    input=relation_input(),
    handler=async fn(action) {
      match action {
        List(issue_id) => respond(() => port.list_relations(issue_id))
        Show(id) => respond(() => port.show_relation(id))
      }
    },
  )
}
