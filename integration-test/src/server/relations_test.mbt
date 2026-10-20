///|
async test "a relation is created, listed, shown and deleted through the tool" {
  let redmine = @livetest.redmine()
  let subject = "redmoon-relations-\{@env.now()}"
  let first = redmine
    |> @issues.create(
      @issues.Create::new(
        project_id=1,
        tracker_id=1,
        status_id=1,
        priority_id=2,
        subject="\{subject}-a",
      ),
    )
  let second = redmine
    |> @issues.create(
      @issues.Create::new(
        project_id=1,
        tracker_id=1,
        status_id=1,
        priority_id=2,
        subject="\{subject}-b",
      ),
    )
  let tools = [@tools.relations_tool(redmine, Full)]
  let outcome : Error? = try {
    exercise_relation(tools, first.id, second.id)
    None
  } catch {
    error => Some(error)
  }
  redmine |> @issues.delete(first.id)
  redmine |> @issues.delete(second.id)
  if outcome is Some(error) {
    raise error
  }
}

///|
async fn exercise_relation(
  tools : Array[@mcp.Tool],
  from : Int32,
  to : Int32,
) -> Unit {
  let created = call_tool(tools, "redmine_issue_relations", {
    "create": { "issue_id": from, "issue_to_id": to, "relation_type": "blocks" },
  })
  assert_eq(created.is_error, false)
  let relation_id = match @json.parse(created.text) {
    { "id": Number(id, ..), .. } => id.to_int()
    _ => fail("the created relation has no id: \{created.text}")
  }
  let listed = call_tool(tools, "redmine_issue_relations", {
    "list": { "issue_id": from },
  })
  assert_true(listed.text.contains("\"issue_to_id\":\{to}"))
  let shown = call_tool(tools, "redmine_issue_relations", {
    "show": { "id": relation_id },
  })
  assert_true(shown.text.contains("\"relation_type\":\"blocks\""))
  let deleted = call_tool(tools, "redmine_issue_relations", {
    "delete": { "id": relation_id },
  })
  assert_eq(deleted.text, "{\"ok\":true}")
}
