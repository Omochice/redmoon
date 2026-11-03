///|
struct FakeTags {
  calls : Array[String]
  listed_issues : Array[(Array[String], Int32?, @issues.StatusFilter?, Int32?)]
  listed_wiki_pages : Array[(@redmine.ProjectRef, String)]
  failure : @redmine.RedmineError?
}

///|
fn FakeTags::new(failure? : @redmine.RedmineError) -> FakeTags {
  { calls: [], listed_issues: [], listed_wiki_pages: [], failure, }
}

///|
fn FakeTags::record(
  self : FakeTags,
  call : String,
) -> Unit raise @redmine.RedmineError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
impl TagPort for FakeTags with fn issue_tags(self, issue_id) {
  self.record("show \{issue_id}")
  ["alpha", "beta"]
}

///|
impl TagPort for FakeTags with fn add_issue_tags(self, issue_id, names) {
  self.record("add \{issue_id} \{names.join(",")}")
  ["alpha", "beta", ..names]
}

///|
impl TagPort for FakeTags with fn remove_issue_tags(self, issue_id, names) {
  self.record("remove \{issue_id} \{names.join(",")}")
  ["alpha", "beta"].filter(name => !names.contains(name))
}

///|
impl TagPort for FakeTags with fn list_issue_tags(self) {
  self.record("list")
  [{ name: "alpha", count: 2, }, { name: "beta", count: 1, }]
}

///|
impl TagPort for FakeTags with fn list_tagged_issues(
  self,
  names,
  project_id,
  status_id,
  limit,
) {
  self.record("list_issues")
  self.listed_issues.push((names, project_id, status_id, limit))
  [fake_issue(1, "first")]
}

///|
fn fake_wiki_page() -> @wiki.PageSummary {
  {
    title: "Guide",
    version: 1,
    created_on: "2026-11-01T00:00:00Z",
    updated_on: "2026-11-02T00:00:00Z",
    parent: None,
  }
}

///|
impl TagPort for FakeTags with fn list_tagged_wiki_pages(self, project, name) {
  self.record("list_wiki_pages")
  self.listed_wiki_pages.push((project, name))
  [fake_wiki_page()]
}

///|
fn tags_tools(fake : FakeTags, mode~ : Mode = Full) -> Array[@mcp.Tool] {
  [tags_tool(fake, mode)]
}

///|
async test "show answers the issue's tag names" {
  let fake = FakeTags::new()
  let called = call_tool(tags_tools(fake), "redmine_tags", {
    "show": { "issue_id": 42 },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "[\"alpha\",\"beta\"]")
  assert_eq(fake.calls, ["show 42"])
}

///|
async test "add and remove pass the names and answer the names after the write" {
  let fake = FakeTags::new()
  let added = call_tool(tags_tools(fake), "redmine_tags", {
    "add": { "issue_id": 42, "tags": ["needs-review"] },
  })
  assert_eq(added.is_error, false)
  assert_eq(added.text, "[\"alpha\",\"beta\",\"needs-review\"]")
  let removed = call_tool(tags_tools(fake), "redmine_tags", {
    "remove": { "issue_id": 42, "tags": ["beta"] },
  })
  assert_eq(removed.is_error, false)
  assert_eq(removed.text, "[\"alpha\"]")
  assert_eq(fake.calls, ["add 42 needs-review", "remove 42 beta"])
}

///|
async test "list answers the catalogue with the number of issues per tag" {
  let fake = FakeTags::new()
  let called = call_tool(tags_tools(fake), "redmine_tags", { "list": {} })
  assert_eq(called.is_error, false)
  assert_eq(
    called.text,
    "[{\"name\":\"alpha\",\"count\":2},{\"name\":\"beta\",\"count\":1}]",
  )
  assert_eq(fake.calls, ["list"])
}

///|
async test "list_issues passes the names and the filters and answers the issues as redmine_issues lists them" {
  let fake = FakeTags::new()
  let called = call_tool(tags_tools(fake), "redmine_tags", {
    "list_issues": {
      "tags": ["alpha", "beta"],
      "project_id": 3,
      "status_id": "closed",
      "limit": 5,
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "[\{fake_issue(1, "first").to_json().stringify()}]")
  ignore(
    call_tool(tags_tools(fake), "redmine_tags", {
      "list_issues": { "tags": ["alpha"], "status_id": 7 },
    }),
  )
  assert_eq(fake.listed_issues, [
    (["alpha", "beta"], Some(3), Some(Closed), Some(5)),
    (["alpha"], None, Some(Id(7)), None),
  ])
}

///|
async test "list_wiki_pages passes the project and the name and answers the pages as redmine_wiki_pages lists them" {
  let fake = FakeTags::new()
  let called = call_tool(tags_tools(fake), "redmine_tags", {
    "list_wiki_pages": { "project_id": "demo", "tag": "howto" },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "[\{fake_wiki_page().to_json().stringify()}]")
  ignore(
    call_tool(tags_tools(fake, mode=Readonly), "redmine_tags", {
      "list_wiki_pages": { "project_id": 3, "tag": "Beta Tag" },
    }),
  )
  assert_eq(fake.listed_wiki_pages, [
    (Identifier("demo"), "howto"),
    (Id(3), "Beta Tag"),
  ])
}

///|
async test "validation reports the exact message for each rule" {
  let tools = tags_tools(FakeTags::new())
  let cases : Array[(Json, String)] = [
    ({ "show": {} }, "invalid arguments: show.issue_id: is required"),
    (
      { "add": { "issue_id": 0, "tags": ["a"] } },
      "invalid arguments: add.issue_id: must be at least 1",
    ),
    (
      { "add": { "issue_id": 1, "tags": [] } },
      "invalid arguments: add.tags: must have at least 1 items",
    ),
    (
      { "add": { "issue_id": 1, "tags": ["a,b"] } },
      "invalid arguments: add.tags.0: must be a name without a comma and not blank",
    ),
    (
      { "remove": { "issue_id": 1, "tags": ["ok", "  "] } },
      "invalid arguments: remove.tags.1: must be a name without a comma and not blank",
    ),
    (
      { "list_issues": { "tags": ["x,y"] } },
      "invalid arguments: list_issues.tags.0: must be a name without a comma and not blank",
    ),
    (
      { "remove": { "issue_id": 1 } },
      "invalid arguments: remove.tags: is required",
    ),
    (
      { "list_issues": { "tags": [] } },
      "invalid arguments: list_issues.tags: must have at least 1 items",
    ),
    (
      { "list_issues": { "tags": ["a"], "status_id": "pending" } },
      "invalid arguments: list_issues.status_id:",
    ),
    (
      { "list_issues": { "tags": ["a"], "limit": 0 } },
      "invalid arguments: list_issues.limit: must be at least 1",
    ),
    (
      { "list": { "type": "issue" } },
      "invalid arguments: list.type: unknown field",
    ),
    (
      { "list_wiki_pages": { "tag": "howto" } },
      "invalid arguments: list_wiki_pages.project_id: is required",
    ),
    (
      { "list_wiki_pages": { "project_id": "demo" } },
      "invalid arguments: list_wiki_pages.tag: is required",
    ),
    (
      { "list_wiki_pages": { "project_id": "demo", "tag": "a,b" } },
      "invalid arguments: list_wiki_pages.tag: must be a name without a comma and not blank",
    ),
    (
      { "list_wiki_pages": { "project_id": "demo", "tag": " " } },
      "invalid arguments: list_wiki_pages.tag: must be a name without a comma and not blank",
    ),
    (
      { "list_wiki_pages": { "project_id": "demo", "tag": ["howto"] } },
      "invalid arguments: list_wiki_pages.tag:",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "redmine_tags", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
}

///|
async test "readonly mode makes add and remove unknown" {
  let fake = FakeTags::new()
  for action in ["add", "remove"] {
    let arguments : Json = { "issue_id": 42, "tags": ["alpha"] }
    let called = call_tool(
      tags_tools(fake, mode=Readonly),
      "redmine_tags",
      Json::object(Map::from_array([(action, arguments)])),
    )
    assert_eq(
      called.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `\{action}`, one of `show`, `list`, `list_issues` and `list_wiki_pages`\"]}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "a dropped write and a refused list become failure payloads" {
  let dropped = call_tool(
    tags_tools(
      FakeTags::new(
        failure=Decode(
          message="Redmine accepted the update without saving the tags `new`",
        ),
      ),
    ),
    "redmine_tags",
    { "add": { "issue_id": 42, "tags": ["new"] } },
  )
  assert_eq(dropped.is_error, true)
  assert_eq(
    dropped.text,
    "{\"status\":0,\"errors\":[\"Redmine accepted the update without saving the tags `new`\"]}",
  )
  let refused = call_tool(
    tags_tools(
      FakeTags::new(
        failure=Response(status=403, errors=[
          "the tag list needs a Redmine administrator, and the API key may belong to a user who is not one",
        ]),
      ),
    ),
    "redmine_tags",
    { "list": {} },
  )
  assert_eq(refused.is_error, true)
  assert_eq(
    refused.text,
    "{\"status\":403,\"errors\":[\"the tag list needs a Redmine administrator, and the API key may belong to a user who is not one\"]}",
  )
}

///|
async test "tools/list advertises the tags tool in full mode" {
  let listed = list_tools(tags_tools(FakeTags::new()))
  assert_eq(
    listed.stringify(),
    "{\"tools\":[{\"name\":\"redmine_tags\",\"description\":\"Read and change the tags that the Additional Tags plugin puts on Redmine issues, and find wiki pages by tag: `show` answers an issue's tag names, `list` answers every issue tag with the number of issues that carry it, `list_issues` lists the issues carrying any of the given names, and `list_wiki_pages` lists the wiki pages of one project carrying one name.\\n`add` and `remove` attach and detach only the names they are given, matched in any case, and answer the issue's tag names after the write; `add` should reuse a name as `show` returns it, because a name that differs from an existing tag only in case is dropped for a user without create_issue_tags.\\nA tag name must not contain a comma, which the plugin would split into several tags.\\n`list_issues` takes `project_id`, `status_id`, and `limit` as `list` of `redmine_issues` does, lists only open issues unless `status_id` says otherwise, and answers issues of the same shape that carry no tags; `show` reads each issue's tags.\\n`list` needs a Redmine administrator and answers 403 to anyone else, who can learn the names in use from `show` on related issues.\\n`list_wiki_pages` takes `project_id` and a single `tag`, and answers pages as `list` of `redmine_wiki_pages` does; a page's own tags cannot be read.\\nNeeds the Additional Tags plugin with its issue tags, and its wiki tags for `list_wiki_pages`, switched on; reading needs the view_issue_tags permission, `add` and `remove` need edit_issue_tags, and `add` of a name no issue carries yet needs create_issue_tags.\\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"show\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"issue_id\"],\"additionalProperties\":false},\"list\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false},\"list_issues\":{\"type\":\"object\",\"properties\":{\"tags\":{\"type\":\"array\",\"items\":{\"type\":\"string\",\"pattern\":\"^[^,]*\\\\S[^,]*$\"},\"minItems\":1},\"project_id\":{\"type\":\"integer\",\"minimum\":1},\"status_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"enum\":[\"open\",\"closed\",\"*\"]}]},\"limit\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"tags\"],\"additionalProperties\":false},\"list_wiki_pages\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"tag\":{\"type\":\"string\",\"pattern\":\"^[^,]*\\\\S[^,]*$\"}},\"required\":[\"project_id\",\"tag\"],\"additionalProperties\":false},\"add\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1},\"tags\":{\"type\":\"array\",\"items\":{\"type\":\"string\",\"pattern\":\"^[^,]*\\\\S[^,]*$\"},\"minItems\":1}},\"required\":[\"issue_id\",\"tags\"],\"additionalProperties\":false},\"remove\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1},\"tags\":{\"type\":\"array\",\"items\":{\"type\":\"string\",\"pattern\":\"^[^,]*\\\\S[^,]*$\"},\"minItems\":1}},\"required\":[\"issue_id\",\"tags\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "tools/list advertises the tags tool in readonly mode without add and remove" {
  let listed = list_tools(tags_tools(FakeTags::new(), mode=Readonly))
  assert_eq(
    listed.stringify(),
    "{\"tools\":[{\"name\":\"redmine_tags\",\"description\":\"Read the tags that the Additional Tags plugin puts on Redmine issues, and find wiki pages by tag: `show` answers an issue's tag names, `list` answers every issue tag with the number of issues that carry it, `list_issues` lists the issues carrying any of the given names, and `list_wiki_pages` lists the wiki pages of one project carrying one name.\\nA tag name must not contain a comma, which the plugin would split into several tags.\\n`list_issues` takes `project_id`, `status_id`, and `limit` as `list` of `redmine_issues` does, lists only open issues unless `status_id` says otherwise, and answers issues of the same shape that carry no tags; `show` reads each issue's tags.\\n`list` needs a Redmine administrator and answers 403 to anyone else, who can learn the names in use from `show` on related issues.\\n`list_wiki_pages` takes `project_id` and a single `tag`, and answers pages as `list` of `redmine_wiki_pages` does; a page's own tags cannot be read.\\nNeeds the Additional Tags plugin with its issue tags, and its wiki tags for `list_wiki_pages`, switched on, and the view_issue_tags permission.\\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"show\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"issue_id\"],\"additionalProperties\":false},\"list\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false},\"list_issues\":{\"type\":\"object\",\"properties\":{\"tags\":{\"type\":\"array\",\"items\":{\"type\":\"string\",\"pattern\":\"^[^,]*\\\\S[^,]*$\"},\"minItems\":1},\"project_id\":{\"type\":\"integer\",\"minimum\":1},\"status_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"enum\":[\"open\",\"closed\",\"*\"]}]},\"limit\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"tags\"],\"additionalProperties\":false},\"list_wiki_pages\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"tag\":{\"type\":\"string\",\"pattern\":\"^[^,]*\\\\S[^,]*$\"}},\"required\":[\"project_id\",\"tag\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}
