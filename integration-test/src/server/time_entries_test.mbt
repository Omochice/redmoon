///|
async test "a time entry is created, listed, shown, updated, and deleted" {
  let redmine = @livetest.redmine()
  let tools = [@tools.time_entries_tool(redmine, Full)]
  let activity_id = (redmine |> @enumerations.time_entry_activities())[0].id
  let created = call_tool(tools, "redmine_time_entries", {
    "create": {
      "hours": 0.5,
      "project_id": 1,
      "spent_on": "2031-06-15",
      "activity_id": activity_id,
      "comments": "redmoon time entries live test",
    },
  })
  assert_eq(created.is_error, false)
  guard @json.parse(created.text) is { "id": Number(id, ..), .. } else {
    fail("created entry has no id: \{created.text}")
  }
  let entry_id = id.to_int()
  let listed = call_tool(tools, "redmine_time_entries", {
    "list": { "project_id": 1, "spent_on": "2031-06-15" },
  })
  assert_true(listed.text.contains("redmoon time entries live test"))
  let shown = call_tool(tools, "redmine_time_entries", {
    "show": { "id": entry_id },
  })
  assert_true(shown.text.contains("\"hours\":0.5"))
  let updated = call_tool(tools, "redmine_time_entries", {
    "update": { "id": entry_id, "hours": 1 },
  })
  assert_eq(updated.text, "{\"ok\":true}")
  let deleted = call_tool(tools, "redmine_time_entries", {
    "delete": { "id": entry_id },
  })
  assert_eq(deleted.text, "{\"ok\":true}")
}
