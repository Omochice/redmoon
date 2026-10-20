///|
async test "redmine_enumerations reaches the real Redmine" {
  let redmine = @livetest.redmine()
  let called = call(
    @cli.build_server(redmine, true, []),
    "redmine_enumerations",
    { "list_issue_priorities": {} },
  )
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("Normal"))
}
