///|
async test "the demo project lists its own and the global templates of a tracker" {
  let redmine = @livetest.redmine()
  let templates = redmine
    |> @issue_templates.list(Identifier("demo"), tracker_id=1)
  assert_true(templates.project.any(fn(t) { t.title == "Bug report" }))
  assert_true(templates.global.any(fn(t) { t.title == "Global bug report" }))
}

///|
async test "a subproject lists the templates its parent shares" {
  let redmine = @livetest.redmine()
  let templates = redmine
    |> @issue_templates.list(Identifier("demo-child"), tracker_id=1)
  assert_true(templates.inherited.any(fn(t) { t.title == "Bug report" }))
  assert_eq(templates.project, [])
}

///|
async test "a missing project raises Response 404" {
  let redmine = @livetest.redmine()
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
