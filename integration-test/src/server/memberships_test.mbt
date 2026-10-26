///|
async test "memberships come from a real Redmine with the principal under its own key" {
  let redmine = @livetest.redmine()
  let tools = [@tools.memberships_tool(redmine)]
  let called = call_tool(tools, "redmine_memberships", {
    "list": { "project_id": "demo" },
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"group\":{\"id\":"))
  assert_true(called.text.contains("\"name\":\"Redmoon team\""))
  assert_true(called.text.contains("\"inherited\":true"))
  let missing = call_tool(tools, "redmine_memberships", {
    "list": { "project_id": "redmoon-no-such-project" },
  })
  assert_eq(missing.is_error, true)
  assert_true(missing.text.contains("\"status\":404"))
}
