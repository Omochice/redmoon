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
