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
  let issue_id = @schema.required("issue_id", record_id())
  let id = @schema.required("id", record_id())
  let entries : Array[(String, @schema.Schema[RelationAction])] = [
    (
      "list",
      @schema.record([issue_id.as_member()], v => {
        RelationAction::List(v.get(issue_id))
      }),
    ),
    (
      "show",
      @schema.record([id.as_member()], v => RelationAction::Show(v.get(id))),
    ),
  ]
  if mode is Full {
    let issue_to_id = @schema.required("issue_to_id", record_id())
    let relation_type = @schema.required(
      "relation_type",
      relation_type_schema(),
    )
    let delay = @schema.optional("delay", @schema.integer())
    entries.push(
      (
        "create",
        @schema.record(
          [
            issue_id.as_member(),
            issue_to_id.as_member(),
            relation_type.as_member(),
            delay.as_member(),
          ],
          v => {
            RelationAction::Create(
              v.get(issue_id),
              v.get(issue_to_id),
              v.get(relation_type),
              v.get(delay),
            )
          },
        ),
      ),
    )
    entries.push(
      (
        "delete",
        @schema.record([id.as_member()], v => RelationAction::Delete(v.get(id))),
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
