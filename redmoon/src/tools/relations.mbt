///|
priv enum RelationAction {
  List(Int32)
  Show(Int32)
  Create(Int32, Int32, @redmine.RelationType, Int32?)
  Delete(Int32)
}

///|
fn relation_type_schema() -> @schema.Schema[@redmine.RelationType] {
  @schema.choice([
    ("relates", @redmine.RelationType::Relates),
    ("duplicates", @redmine.RelationType::Duplicates),
    ("duplicated", @redmine.RelationType::Duplicated),
    ("blocks", @redmine.RelationType::Blocks),
    ("blocked", @redmine.RelationType::Blocked),
    ("precedes", @redmine.RelationType::Precedes),
    ("follows", @redmine.RelationType::Follows),
    ("copied_to", @redmine.RelationType::CopiedTo),
    ("copied_from", @redmine.RelationType::CopiedFrom),
  ])
}

///|
fn relation_input(mode : Mode) -> @schema.Schema[RelationAction] {
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
  if mode is Full {
    entries.push(
      (
        "create",
        @schema.object(issue_id => {
          issue_to_id => {
            relation_type => {
              delay => Create(issue_id, issue_to_id, relation_type, delay)
            }
          }
        })
        |> @schema.field("issue_id", record_id())
        |> @schema.field("issue_to_id", record_id())
        |> @schema.field("relation_type", relation_type_schema())
        |> @schema.optional("delay", @schema.integer())
        |> @schema.Obj::done,
      ),
    )
    entries.push(
      (
        "delete",
        @schema.object(id => Delete(id))
        |> @schema.field("id", record_id())
        |> @schema.Obj::done,
      ),
    )
  }
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
    input=relation_input(mode),
    handler=async fn(action) {
      match action {
        List(issue_id) => respond(() => port.list_relations(issue_id))
        Show(id) => respond(() => port.show_relation(id))
        Create(issue_id, issue_to_id, relation_type, delay) =>
          respond(() => {
            port.create_relation(issue_id, issue_to_id, relation_type, delay)
          })
        Delete(id) => respond_ok(() => port.delete_relation(id))
      }
    },
  )
}
