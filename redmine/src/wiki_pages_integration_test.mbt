///|
fn wiki_live() -> @redmine.Redmine? raise @redmine.RedmineError {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return None
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return None
  }
  Some(@redmine.Redmine::new(endpoint~, api_key~))
}

///|
fn wiki_unique_title(prefix : String) -> String {
  "\{prefix} \{@async.now()}"
}

///|
async test "live: wiki pages go through create, list, show, update and delete" {
  guard wiki_live() is Some(redmine) else { return }
  let title = wiki_unique_title("Redmoon wiki")
  let stored = title.replace_all(old=" ", new="_")
  for project in [@redmine.Identifier("demo"), @redmine.Id(1)] {
    redmine.create_wiki_page(project, title, "first", comments="created")
    defer redmine.delete_wiki_page(project, title)
    assert_true(
      redmine
      .list_wiki_pages(project)
      .any(fn(page) { page.title.to_lower() == stored.to_lower() }),
    )
    let page = redmine.show_wiki_page(project, title)
    assert_eq(page.text, "first")
    assert_eq(page.version, 1)
    redmine.update_wiki_page(project, title, "second", version=1)
    assert_eq(redmine.show_wiki_page(project, title).text, "second")
    let old = redmine.show_wiki_page(project, title, version=1)
    assert_eq(old.text, "first")
    try redmine.update_wiki_page(project, title, "stale", version=1) catch {
      Response(status~, ..) => assert_eq(status, 409)
      _ => fail("expected Response")
    } noraise {
      _ => fail("expected a conflict")
    }
  }
}

///|
async test "live: a missing wiki page raises Response 404" {
  guard wiki_live() is Some(redmine) else { return }
  try
    redmine.show_wiki_page(@redmine.Identifier("demo"), "No such page")
  catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
async test "live: a title with dots and spaces is shown by the title it was created with" {
  guard wiki_live() is Some(redmine) else { return }
  let project = @redmine.Identifier("demo")
  let title = "Release v1.0 \{wiki_unique_title("round")}"
  redmine.create_wiki_page(project, title, "body")
  defer redmine.delete_wiki_page(project, title)
  assert_eq(redmine.show_wiki_page(project, title).text, "body")
  let stored = title.replace_all(old=" ", new="_").replace_all(old=".", new="")
  assert_true(
    redmine
    .list_wiki_pages(project)
    .any(fn(page) { page.title.to_lower() == stored.to_lower() }),
  )
}
