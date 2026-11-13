///|
async test "versions go through create, list, show, update and delete" {
  let redmine = @livetest.redmine()
  for
    project in [
      @redmine.ProjectRef::Identifier("demo"),
      @redmine.ProjectRef::Id(1),
    ] {
    let name = "redmoon version \{@async.now()}"
    let created = redmine
      |> @versions.create(
        project,
        @versions.Create::new(
          name~,
          description="made by a test",
          status=Open,
          due_date="2030-01-31",
          sharing=Descendants,
        ),
      )
    defer (@async.protect_from_cancel(() => {
      redmine |> @versions.delete(created.id)
    }) catch {
      _ => ()
    })
    assert_eq(created.name, name)
    assert_eq(created.due_date, Some("2030-01-31"))
    assert_eq(created.sharing, Descendants)
    assert_true(
      (redmine |> @versions.list(project)).any(fn(v) { v.id == created.id }),
    )
    redmine
    |> @versions.update(
      created.id,
      @versions.Update::new(description=Set("changed"), status=Locked),
    )
    let shown = redmine |> @versions.show(created.id)
    assert_eq(shown.description, Some("changed"))
    assert_eq(shown.status, Locked)
    assert_eq(shown.name, name)
    redmine |> @versions.delete(created.id)
    try redmine |> @versions.show(created.id) catch {
      Response(status~, ..) => assert_eq(status, 404)
      _ => fail("expected Response")
    } noraise {
      _ => fail("the deleted version is still shown")
    }
  }
}

///|
async test "a missing version raises Response 404" {
  let redmine = @livetest.redmine()
  try redmine |> @versions.show(0) catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
