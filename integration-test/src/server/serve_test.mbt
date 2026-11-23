///|
async test "redmine_enumerations reaches the real Redmine" {
  let redmine = @livetest.redmine()
  let called = call(
    @cli.build_server(redmine, true, []),
    "redmine_enumerations",
    { "list_issue_priorities": {} },
  )
  assert_eq(called.is_error, false, msg=called.text)
  guard @json.parse(called.text) is Array(priorities) else {
    fail("not a listing: \{called.text}")
  }
  assert_true(
    priorities.any(priority => priority is { "name": "Normal", .. }),
    msg=called.text,
  )
}
