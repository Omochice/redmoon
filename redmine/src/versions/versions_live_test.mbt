///|
async test "live: versions go through create, list, show, update and delete" {
  guard @livetest.redmine() is Some(redmine) else { return }
  for
    project in [
      @redmine.ProjectRef::Identifier("demo"),
      @redmine.ProjectRef::Id(1),
    ] {
    let name = "redmoon version \{@async.now()}"
    let created = redmine
      |> @versions.create(project, {
        name,
        description: Some("made by a test"),
        status: Some(Open),
        due_date: Some("2030-01-31"),
        sharing: Some(Descendants),
        wiki_page_title: None,
      })
    defer redmine |> @versions.delete(created.id)
    assert_eq(created.name, name)
    assert_eq(created.due_date, Some("2030-01-31"))
    assert_eq(created.sharing, Descendants)
    assert_true(
      (redmine |> @versions.list(project)).any(fn(v) { v.id == created.id }),
    )
    redmine
    |> @versions.update(created.id, {
      name: None,
      description: Some("changed"),
      status: Some(Locked),
      due_date: None,
      sharing: None,
      wiki_page_title: None,
    })
    let shown = redmine |> @versions.show(created.id)
    assert_eq(shown.description, Some("changed"))
    assert_eq(shown.status, Locked)
    assert_eq(shown.name, name)
  }
}

///|
async test "live: a missing version raises Response 404" {
  guard @livetest.redmine() is Some(redmine) else { return }
  try redmine |> @versions.show(0) catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
