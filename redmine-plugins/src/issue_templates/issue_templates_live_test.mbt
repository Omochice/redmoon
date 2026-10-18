///|
async test "live: the demo project lists its own and the global templates of a tracker" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let templates = redmine
    |> @issue_templates.list(Identifier("demo"), tracker_id=1)
  assert_true(templates.project.any(fn(t) { t.title == "Bug report" }))
  assert_true(templates.global.any(fn(t) { t.title == "Global bug report" }))
}

///|
async test "live: a subproject lists the templates its parent shares" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let templates = redmine
    |> @issue_templates.list(Identifier("demo-child"), tracker_id=1)
  assert_true(templates.inherited.any(fn(t) { t.title == "Bug report" }))
  assert_eq(templates.project, [])
}

///|
async test "live: a missing project raises Response 404" {
  guard @livetest.redmine() is Some(redmine) else { return }
  try
    redmine
    |> @issue_templates.list(Identifier("no-such-project"), tracker_id=1)
  catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
