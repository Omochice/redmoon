///|
async test "a missing record raises Response 404" {
  let redmine = @livetest.redmine()
  try @redmine.send(redmine, Get, ["issues", "0.json"]) catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
