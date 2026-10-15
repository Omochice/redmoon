///|
fn live_redmine() -> @redmine.Redmine? raise @redmine.RedmineError {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return None
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return None
  }
  Some(@redmine.Redmine::new(endpoint~, api_key~))
}

///|
async test "live: issue priorities include Normal" {
  guard live_redmine() is Some(redmine) else { return }
  let priorities = redmine.list_issue_priorities()
  assert_true(priorities.any(fn(p) { p.name == "Normal" }))
}

///|
async test "live: time entry activities are listed" {
  guard live_redmine() is Some(redmine) else { return }
  assert_false(redmine.list_time_entry_activities().is_empty())
}

///|
async test "live: document categories are listed" {
  guard live_redmine() is Some(redmine) else { return }
  assert_false(redmine.list_document_categories().is_empty())
}
