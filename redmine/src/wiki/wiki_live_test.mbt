///|
fn wiki_unique_title(prefix : String) -> String {
  "\{prefix} \{@async.now()}"
}

///|
async test "live: wiki pages go through create, list, show, update and delete" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let title = wiki_unique_title("Redmoon wiki")
  let stored = title.replace_all(old=" ", new="_")
  for
    project in [
      @redmine.ProjectRef::Identifier("demo"),
      @redmine.ProjectRef::Id(1),
    ] {
    redmine |> @wiki.create(project, title, "first", comments="created")
    defer redmine |> @wiki.delete(project, title)
    assert_true(
      (redmine |> @wiki.list(project)).any(fn(page) {
        page.title.to_lower() == stored.to_lower()
      }),
    )
    let page = redmine |> @wiki.show(project, title)
    assert_eq(page.text, "first")
    assert_eq(page.version, 1)
    redmine |> @wiki.update(project, title, "second", version=1)
    assert_eq((redmine |> @wiki.show(project, title)).text, "second")
    let old = redmine |> @wiki.show(project, title, version=1)
    assert_eq(old.text, "first")
    try redmine |> @wiki.update(project, title, "stale", version=1) catch {
      Response(status~, ..) => assert_eq(status, 409)
      _ => fail("expected Response")
    } noraise {
      _ => fail("expected a conflict")
    }
  }
}

///|
async test "live: a missing wiki page raises Response 404" {
  guard @livetest.redmine() is Some(redmine) else { return }
  try
    redmine
    |> @wiki.show(@redmine.ProjectRef::Identifier("demo"), "No such page")
  catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
async test "live: a title with dots and spaces is shown by the title it was created with" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let project = @redmine.ProjectRef::Identifier("demo")
  let title = "Release v1.0 \{wiki_unique_title("round")}"
  redmine |> @wiki.create(project, title, "body")
  defer redmine |> @wiki.delete(project, title)
  assert_eq((redmine |> @wiki.show(project, title)).text, "body")
  let stored = title.replace_all(old=" ", new="_").replace_all(old=".", new="")
  assert_true(
    (redmine |> @wiki.list(project)).any(fn(page) {
      page.title.to_lower() == stored.to_lower()
    }),
  )
}
