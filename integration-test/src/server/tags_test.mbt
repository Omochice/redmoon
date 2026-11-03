///|
/// A server as `serve --plugin additional_tags` builds it for `redmine`, so that the tool is reached the way a model reaches it.
fn tags_server(redmine : @redmine.Redmine) -> @mcp.Server {
  @cli.build_server(redmine, false, [@cli.AdditionalTags])
}

///|
async test "a tag added through the tool is shown, listed, found, and removed" {
  let redmine = @livetest.redmine()
  let id = @livetest.create_probe_issue(redmine, "tags tool round trip")
  defer @livetest.delete_probe_issue(redmine, id)
  let added = call(tags_server(redmine), "redmine_tags", {
    "add": { "issue_id": id, "tags": ["  Redmoon-Probe-Tool  "] },
  })
  assert_eq(added.is_error, false, msg=added.text)
  assert_eq(added.text, "[\"Redmoon-Probe-Tool\"]")
  let shown = call(tags_server(redmine), "redmine_tags", {
    "show": { "issue_id": id },
  })
  assert_eq(shown.text, "[\"Redmoon-Probe-Tool\"]")
  let catalogue = call(tags_server(redmine), "redmine_tags", { "list": {} })
  assert_eq(catalogue.is_error, false, msg=catalogue.text)
  assert_true(
    catalogue.text.contains("{\"name\":\"Redmoon-Probe-Tool\",\"count\":1}"),
  )
  let found = call(tags_server(redmine), "redmine_tags", {
    "list_issues": { "tags": ["redmoon-probe-tool"] },
  })
  assert_eq(found.is_error, false, msg=found.text)
  assert_true(found.text.contains("\"id\":\{id}"))
  let removed = call(tags_server(redmine), "redmine_tags", {
    "remove": { "issue_id": id, "tags": ["REDMOON-PROBE-TOOL"] },
  })
  assert_eq(removed.text, "[]")
}

///|
async test "a member who may create tags adds a new name through the tool" {
  let redmine = @livetest.redmine()
  let tagger = @livetest.as_tagger()
  let id = @livetest.create_probe_issue(redmine, "tags tool create")
  defer @livetest.delete_probe_issue(redmine, id)
  let added = call(tags_server(tagger), "redmine_tags", {
    "add": { "issue_id": id, "tags": ["redmoon-probe-tool-created"] },
  })
  assert_eq(added.is_error, false, msg=added.text)
  assert_eq(added.text, "[\"redmoon-probe-tool-created\"]")
  let shown = call(tags_server(redmine), "redmine_tags", {
    "show": { "issue_id": id },
  })
  assert_eq(shown.text, "[\"redmoon-probe-tool-created\"]")
}

///|
async test "a member is told through the tool that the tag list needs an administrator" {
  let colleague = @livetest.as_member()
  let denied = call(tags_server(colleague), "redmine_tags", { "list": {} })
  assert_eq(denied.is_error, true)
  assert_true(denied.text.contains("\"status\":403"))
  assert_true(denied.text.contains("administrator"))
}

///|
/// The SDK cannot write wiki tags, so the page is tagged by a request built here.
/// Redmine refuses `tag_list` without the page text, so the request carries both.
async test "a tagged wiki page is found through the tool in any case" {
  let redmine = @livetest.redmine()
  let title = "Redmoon_probe_tool_wiki_tag_\{@env.now()}"
  let page = ["projects", "demo", "wiki", "\{title}.json"]
  ignore(
    @redmine.send(redmine, Put, page, body={
      "wiki_page": { "text": "probe", "tag_list": ["redmoon-probe-tool-wiki"] },
    }),
  )
  defer ignore(@redmine.send(redmine, Delete, page))
  let found = call(tags_server(redmine), "redmine_tags", {
    "list_wiki_pages": {
      "project_id": "demo",
      "tag": "REDMOON-PROBE-TOOL-WIKI",
    },
  })
  assert_eq(found.is_error, false, msg=found.text)
  assert_true(found.text.contains("\"title\":\"\{title}\""))
  let none = call(tags_server(redmine), "redmine_tags", {
    "list_wiki_pages": {
      "project_id": "demo",
      "tag": "redmoon-probe-tool-nobody",
    },
  })
  assert_eq(none.text, "[]")
}
