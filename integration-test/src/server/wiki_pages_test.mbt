///|
async test "wiki pages go through the tool" {
  let redmine = @livetest.redmine()
  let tools = [@tools.wiki_pages_tool(redmine, @tools.LocalFile::new(), Full)]
  let title = "Redmoon tool \{@async.now()}"
  let created = call_tool(tools, "redmine_wiki_pages", {
    "create": { "project_id": "demo", "title": title, "text": "first" },
  })
  assert_eq(created.text, "{\"ok\":true}")
  defer ignore(
    call_tool(tools, "redmine_wiki_pages", {
      "delete": { "project_id": "demo", "title": title },
    }),
  )
  let shown = call_tool(tools, "redmine_wiki_pages", {
    "show": { "project_id": 1, "title": title },
  })
  assert_true(shown.text.contains("\"text\":\"first\""))
  let listed = call_tool(tools, "redmine_wiki_pages", {
    "list": { "project_id": "demo" },
  })
  assert_true(listed.text.contains(title.replace_all(old=" ", new="_")))
  let missing = call_tool(tools, "redmine_wiki_pages", {
    "show": { "project_id": "demo", "title": "No such \{title}" },
  })
  assert_eq(missing.is_error, true)
  assert_true(missing.text.contains("\"status\":404"))
}

///|
async test "a wiki text saved by show and sent back from the file is stored unchanged" {
  let redmine = @livetest.redmine()
  let project = @redmine.ProjectRef::Identifier("demo")
  let title = "Redmoon_round_trip_\{@async.now()}"
  let content = "h1. Heading\n\nfirst line\nsecond line\n"
  redmine |> @wiki.create(project, title, content)
  defer ((redmine |> @wiki.delete(project, title)) catch { _ => () })
  let stored = (redmine |> @wiki.show(project, title)).text
  let tools = [@tools.wiki_pages_tool(redmine, @tools.LocalFile::new(), Full)]
  with_scratch_dir(async fn(dir) {
    let path = "\{dir}/page.textile"
    let shown = call_tool(tools, "redmine_wiki_pages", {
      "show": { "project_id": "demo", "title": title, "text_path": path },
    })
    assert_eq(shown.is_error, false, msg=shown.text)
    guard @json.parse(shown.text) is Object(fields) else {
      fail("not an object: \{shown.text}")
    }
    assert_true(fields.get("text_path") is Some(String(_)))
    assert_false(fields.contains("text"))
    assert_eq(@fs.read_file(path).text(), content)
    let updated = call_tool(tools, "redmine_wiki_pages", {
      "update": { "project_id": "demo", "title": title, "text_path": path },
    })
    assert_eq(updated.text, "{\"ok\":true}")
    assert_eq((redmine |> @wiki.show(project, title)).text, stored)
  })
}
