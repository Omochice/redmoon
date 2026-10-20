///|
async test "issue templates come through the tool" {
  let redmine = @livetest.redmine()
  let tools = [@tools.issue_templates_tool(redmine)]
  let called = call_tool(tools, "redmine_issue_templates", {
    "list": { "project_id": "demo", "tracker_id": 1 },
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"title\":\"Bug report\""))
  assert_true(called.text.contains("\"title\":\"Global bug report\""))
  let missing = call_tool(tools, "redmine_issue_templates", {
    "list": { "project_id": "no-such-project", "tracker_id": 1 },
  })
  assert_eq(missing.is_error, true)
  assert_true(missing.text.contains("\"status\":404"))
}
