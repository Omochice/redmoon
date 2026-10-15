///|
fn versions_live() -> @redmine.Redmine? raise @redmine.RedmineError {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return None
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return None
  }
  Some(@redmine.Redmine::new(endpoint~, api_key~))
}

///|
async test "live: versions go through create, list, show, update and delete" {
  guard versions_live() is Some(redmine) else { return }
  for project in [@redmine.Identifier("demo"), @redmine.Id(1)] {
    let name = "redmoon version \{@async.now()}"
    let created = redmine.create_version(project, {
      name,
      description: Some("made by a test"),
      status: Some(Open),
      due_date: Some("2030-01-31"),
      sharing: Some(Descendants),
      wiki_page_title: None,
    })
    defer redmine.delete_version(created.id)
    assert_eq(created.name, name)
    assert_eq(created.due_date, Some("2030-01-31"))
    assert_eq(created.sharing, Descendants)
    assert_true(
      redmine.list_versions(project).any(fn(v) { v.id == created.id }),
    )
    redmine.update_version(created.id, {
      name: None,
      description: Some("changed"),
      status: Some(Locked),
      due_date: None,
      sharing: None,
      wiki_page_title: None,
    })
    let shown = redmine.show_version(created.id)
    assert_eq(shown.description, Some("changed"))
    assert_eq(shown.status, Locked)
    assert_eq(shown.name, name)
  }
}

///|
async test "live: a missing version raises Response 404" {
  guard versions_live() is Some(redmine) else { return }
  try redmine.show_version(0) catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
