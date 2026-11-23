///|
async test "a time entry is created, listed, shown, updated, and deleted" {
  let redmine = @livetest.redmine()
  @livetest.ensure_time_tracking(redmine)
  let tools = [@tools.time_entries_tool(redmine, Full)]
  let activity_id = (redmine |> @enumerations.time_entry_activities())[0].id
  let comments = "redmoon time entries live test \{@env.now()}"
  let created = call_tool(tools, "redmine_time_entries", {
    "create": {
      "hours": 0.5,
      "project_id": 1,
      "spent_on": "2031-06-15",
      "activity_id": activity_id,
      "comments": comments,
    },
  })
  assert_eq(created.is_error, false, msg=created.text)
  guard @json.parse(created.text) is { "id": Number(id, ..), .. } else {
    fail("created entry has no id: \{created.text}")
  }
  let entry_id = id.to_int()
  defer @livetest.cleanup(() => {
    ignore(@redmine.send(redmine, Delete, ["time_entries", "\{entry_id}.json"]))
  })
  let listed = call_tool(tools, "redmine_time_entries", {
    "list": { "project_id": 1, "spent_on": "2031-06-15" },
  })
  assert_eq(listed.is_error, false, msg=listed.text)
  guard @json.parse(listed.text) is Array(entries) else {
    fail("not a listing: \{listed.text}")
  }
  assert_true(
    entries.any(entry => {
      entry is { "id": Number(found, ..), "comments": String(text), .. } &&
      found.to_int() == entry_id &&
      text == comments
    }),
    msg=listed.text,
  )
  let shown = call_tool(tools, "redmine_time_entries", {
    "show": { "id": entry_id },
  })
  assert_true(@json.parse(shown.text) is { "hours": Number(0.5, ..), .. })
  let updated = call_tool(tools, "redmine_time_entries", {
    "update": { "id": entry_id, "hours": 1 },
  })
  assert_eq(updated.text, "{\"ok\":true}")
  let reshown = call_tool(tools, "redmine_time_entries", {
    "show": { "id": entry_id },
  })
  assert_true(
    @json.parse(reshown.text) is { "hours": Number(1, ..), .. },
    msg=reshown.text,
  )
  let deleted = call_tool(tools, "redmine_time_entries", {
    "delete": { "id": entry_id },
  })
  assert_eq(deleted.text, "{\"ok\":true}")
}
