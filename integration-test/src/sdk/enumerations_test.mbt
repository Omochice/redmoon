///|
async test "issue priorities include Normal" {
  let redmine = @livetest.redmine()
  let priorities = redmine |> @enumerations.issue_priorities()
  assert_true(priorities.any(fn(p) { p.name == "Normal" }))
}

///|
async test "time entry activities are listed" {
  let redmine = @livetest.redmine()
  assert_false((redmine |> @enumerations.time_entry_activities()).is_empty())
}

///|
async test "document categories are listed" {
  let redmine = @livetest.redmine()
  assert_false((redmine |> @enumerations.document_categories()).is_empty())
}
