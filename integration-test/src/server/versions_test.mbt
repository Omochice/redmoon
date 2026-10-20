///|
async test "versions go through the tool" {
  let redmine = @livetest.redmine()
  let tools = [@tools.versions_tool(redmine, Full)]
  let name = "redmoon-tool-\{@async.now()}"
  let created = call_tool(tools, "redmine_versions", {
    "create": {
      "project_id": "demo",
      "name": name,
      "due_date": "2030-01-31",
      "sharing": "none",
    },
  })
  assert_eq(created.is_error, false)
  guard @json.parse(created.text) is { "id": Number(id, ..), .. } else {
    fail("no id in \{created.text}")
  }
  let id = id.to_int()
  defer ignore(call_tool(tools, "redmine_versions", { "delete": { "id": id } }))
  let updated = call_tool(tools, "redmine_versions", {
    "update": { "id": id, "status": "locked" },
  })
  assert_eq(updated.text, "{\"ok\":true}")
  let shown = call_tool(tools, "redmine_versions", { "show": { "id": id } })
  assert_true(shown.text.contains("\"status\":\"locked\""))
  assert_true(shown.text.contains("\"due_date\":\"2030-01-31\""))
  let listed = call_tool(tools, "redmine_versions", {
    "list": { "project_id": 1 },
  })
  assert_true(listed.text.contains(name))
  let missing = call_tool(tools, "redmine_versions", {
    "show": { "id": 2000000000 },
  })
  assert_eq(missing.is_error, true)
  assert_true(missing.text.contains("\"status\":404"))
}
