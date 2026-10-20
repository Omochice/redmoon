///|
async test "a search finds an issue created for the test" {
  let redmine = @livetest.redmine()
  let subject = "redmoon-search-\{@env.now()}"
  let created = redmine
    |> @issues.create(
      @issues.Create::new(
        project_id=1,
        tracker_id=1,
        status_id=1,
        priority_id=2,
        subject~,
      ),
    )
  let outcome : Error? = try {
    let called = call_tool([@tools.search_tool(redmine)], "redmine_search", {
      "search": { "q": subject, "issues": true },
    })
    assert_eq(called.is_error, false)
    assert_true(called.text.contains(subject))
    None
  } catch {
    error => Some(error)
  }
  redmine |> @issues.delete(created.id)
  if outcome is Some(error) {
    raise error
  }
}
