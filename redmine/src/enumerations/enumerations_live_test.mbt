///|
async test "live: issue priorities include Normal" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let priorities = redmine |> @enumerations.issue_priorities()
  assert_true(priorities.any(fn(p) { p.name == "Normal" }))
}

///|
async test "live: time entry activities are listed" {
  guard @livetest.redmine() is Some(redmine) else { return }
  assert_false((redmine |> @enumerations.time_entry_activities()).is_empty())
}

///|
async test "live: document categories are listed" {
  guard @livetest.redmine() is Some(redmine) else { return }
  assert_false((redmine |> @enumerations.document_categories()).is_empty())
}
