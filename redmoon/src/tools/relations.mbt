///|
priv enum RelationAction {
  List(Int32)
  Show(Int32)
  Create(Int32, Int32, @relations.Type, Int32?)
  Delete(Int32)
}

///|
fn relation_type_schema() -> @schema.Schema[@relations.Type] {
  @schema.choice([
    ("relates", @relations.Type::Relates),
    ("duplicates", @relations.Type::Duplicates),
    ("duplicated", @relations.Type::Duplicated),
    ("blocks", @relations.Type::Blocks),
    ("blocked", @relations.Type::Blocked),
    ("precedes", @relations.Type::Precedes),
    ("follows", @relations.Type::Follows),
    ("copied_to", @relations.Type::CopiedTo),
    ("copied_from", @relations.Type::CopiedFrom),
  ])
}

///|
fn relation_input(mode : Mode) -> @schema.Schema[RelationAction] {
  let issue_id = @schema.required("issue_id", record_id())
  let id = @schema.required("id", record_id())
  let read = [
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
  let issue_to_id = @schema.required("issue_to_id", record_id())
  let relation_type = @schema.required("relation_type", relation_type_schema())
  let delay = @schema.optional("delay", @schema.integer())
  let write = [
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
    (
      "delete",
      @schema.record([id.as_member()], v => RelationAction::Delete(v.get(id))),
    ),
  ]
  actions(mode, read~, write~)
}

///|
/// `redmine_issue_relations`: the links between issues.
pub fn relations_tool(port : &RelationPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_issue_relations",
    description=describe_crud_tool(
      "issue relations",
      mode,
      full_verbs="Create, read, and delete",
    ),
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
