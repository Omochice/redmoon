///|
struct FakeWikiPages {
  calls : Array[String]
  failure : @redmine.RedmineError?
}

///|
fn FakeWikiPages::new(failure? : @redmine.RedmineError) -> FakeWikiPages {
  { calls: [], failure, }
}

///|
fn FakeWikiPages::record(
  self : FakeWikiPages,
  call : String,
) -> Unit raise @redmine.RedmineError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn wiki_project_label(project : @redmine.ProjectRef) -> String {
  match project {
    Id(id) => id.to_string()
    Identifier(name) => name
  }
}

///|
fn[T : Show] wiki_option_label(value : T?) -> String {
  match value {
    Some(v) => "\{v}"
    None => "-"
  }
}

///|
impl WikiPagePort for FakeWikiPages with fn list_wiki_pages(self, project) {
  self.record("list \{wiki_project_label(project)}")
  [
    {
      title: "Home",
      version: 2,
      created_on: "2026-01-01T00:00:00Z",
      updated_on: "2026-01-02T00:00:00Z",
      parent: Some({ title: "Root", }),
    },
  ]
}

///|
impl WikiPagePort for FakeWikiPages with fn show_wiki_page(
  self,
  project,
  title,
  version?,
) {
  self.record(
    "show \{wiki_project_label(project)} \{title} \{wiki_option_label(version)}",
  )
  {
    title,
    version: 2,
    text: "hello",
    author: { id: 1, name: "Admin", },
    comments: None,
    created_on: "2026-01-01T00:00:00Z",
    updated_on: "2026-01-02T00:00:00Z",
    attachments: None,
  }
}

///|
impl WikiPagePort for FakeWikiPages with fn create_wiki_page(
  self,
  project,
  title,
  text,
  comments?,
  parent_title?,
) {
  self.record(
    "create \{wiki_project_label(project)} \{title} \{text} \{wiki_option_label(comments)} \{wiki_option_label(parent_title)}",
  )
}

///|
impl WikiPagePort for FakeWikiPages with fn update_wiki_page(
  self,
  project,
  title,
  text,
  comments?,
  version?,
  parent_title?,
) {
  self.record(
    "update \{wiki_project_label(project)} \{title} \{text} \{wiki_option_label(comments)} \{wiki_option_label(version)} \{wiki_option_label(parent_title)}",
  )
}

///|
impl WikiPagePort for FakeWikiPages with fn delete_wiki_page(
  self,
  project,
  title,
) {
  self.record("delete \{wiki_project_label(project)} \{title}")
}

///|
fn wiki_tools(
  fake : FakeWikiPages,
  mode~ : Mode = Full,
  files~ : FakeFiles = FakeFiles::new(),
) -> Array[@mcp.Tool] {
  [wiki_pages_tool(fake, files, mode)]
}

///|
async test "list and show pass the project, the title, and the version" {
  let fake = FakeWikiPages::new()
  let tools = wiki_tools(fake)
  let listed = call_tool(tools, "redmine_wiki_pages", {
    "list": { "project_id": "demo" },
  })
  assert_eq(listed.is_error, false)
  assert_eq(
    listed.text,
    "[{\"title\":\"Home\",\"version\":2,\"created_on\":\"2026-01-01T00:00:00Z\",\"updated_on\":\"2026-01-02T00:00:00Z\",\"parent\":{\"title\":\"Root\"}}]",
  )
  let shown = call_tool(tools, "redmine_wiki_pages", {
    "show": { "project_id": 1, "title": "My Page" },
  })
  assert_true(shown.text.contains("\"text\":\"hello\""))
  ignore(
    call_tool(tools, "redmine_wiki_pages", {
      "show": { "project_id": 1, "title": "My Page", "version": 3 },
    }),
  )
  assert_eq(fake.calls, ["list demo", "show 1 My Page -", "show 1 My Page 3"])
}

///|
async test "create and update answer ok and pass every argument" {
  let fake = FakeWikiPages::new()
  let tools = wiki_tools(fake)
  let created = call_tool(tools, "redmine_wiki_pages", {
    "create": {
      "project_id": "demo",
      "title": "Page",
      "text": "body",
      "comments": "why",
      "parent_title": "Root",
    },
  })
  assert_eq(created.is_error, false)
  assert_eq(created.text, "{\"ok\":true}")
  let bare = call_tool(tools, "redmine_wiki_pages", {
    "create": { "project_id": "demo", "title": "Page", "text": "body" },
  })
  assert_eq(bare.text, "{\"ok\":true}")
  let updated = call_tool(tools, "redmine_wiki_pages", {
    "update": {
      "project_id": 1,
      "title": "Page",
      "text": "new",
      "comments": "c",
      "version": 4,
      "parent_title": "P",
    },
  })
  assert_eq(updated.text, "{\"ok\":true}")
  assert_eq(fake.calls, [
    "create demo Page body why Root", "create demo Page body - -", "update 1 Page new c 4 P",
  ])
}

///|
async test "delete answers ok" {
  let fake = FakeWikiPages::new()
  let deleted = call_tool(wiki_tools(fake), "redmine_wiki_pages", {
    "delete": { "project_id": "demo", "title": "Page" },
  })
  assert_eq(deleted.text, "{\"ok\":true}")
  assert_eq(fake.calls, ["delete demo Page"])
}

///|
async test "a blank title is rejected for every action that takes one" {
  let fake = FakeWikiPages::new()
  let tools = wiki_tools(fake)
  let blank : Array[(String, Json)] = [
    ("show", { "project_id": 1, "title": "  " }),
    ("create", { "project_id": 1, "title": "  ", "text": "t" }),
    ("update", { "project_id": 1, "title": "  ", "text": "t" }),
    ("delete", { "project_id": 1, "title": "  " }),
  ]
  for entry in blank {
    let called = call_tool(
      tools,
      "redmine_wiki_pages",
      Json::object(Map([(entry.0, entry.1)])),
    )
    assert_eq(called.is_error, true)
    assert_eq(
      called.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: \{entry.0}.title: must not be blank\"]}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "validation reports missing fields, bad projects, and bad versions" {
  let tools = wiki_tools(FakeWikiPages::new())
  let missing = call_tool(tools, "redmine_wiki_pages", {
    "create": { "project_id": 1, "title": "T" },
  })
  assert_eq(
    missing.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: create.text_path: one of `text` and `text_path` is required\"]}",
  )
  let spaced = call_tool(tools, "redmine_wiki_pages", {
    "list": { "project_id": "a b" },
  })
  assert_eq(spaced.is_error, true)
  let zero = call_tool(tools, "redmine_wiki_pages", {
    "show": { "project_id": 1, "title": "T", "version": 0 },
  })
  assert_eq(zero.is_error, true)
  let stray = call_tool(tools, "redmine_wiki_pages", {
    "delete": { "project_id": 1, "title": "T", "text": "x" },
  })
  assert_eq(
    stray.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: delete.text: unknown field\"]}",
  )
}

///|
async test "readonly mode makes the write actions unknown" {
  let fake = FakeWikiPages::new()
  let tools = wiki_tools(fake, mode=Readonly)
  let called = call_tool(tools, "redmine_wiki_pages", {
    "delete": { "project_id": 1, "title": "T" },
  })
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `delete`, one of: list, show\"]}",
  )
  assert_eq(fake.calls, [])
}

///|
async test "a Redmine failure becomes a failure payload" {
  let tools = wiki_tools(
    FakeWikiPages::new(failure=Response(status=409, errors=["Conflict"])),
  )
  let requests : Array[Json] = [
    { "list": { "project_id": 1 } },
    { "update": { "project_id": 1, "title": "T", "text": "x" } },
  ]
  for arguments in requests {
    let called = call_tool(tools, "redmine_wiki_pages", arguments)
    assert_eq(called.is_error, true)
    assert_eq(called.text, "{\"status\":409,\"errors\":[\"Conflict\"]}")
  }
}

///|
async test "tools/list advertises the wiki tool in full mode" {
  let listed = list_tools(wiki_tools(FakeWikiPages::new()))
  assert_eq(
    listed.stringify(),
    "{\"tools\":[{\"name\":\"redmine_wiki_pages\",\"description\":\"Create, read, update, and delete Redmine wiki pages. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\\nFor a long page, `create` and `update` take `text_path`, the path of a local UTF-8 file, instead of `text` (absolute is recommended).\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"}},\"required\":[\"project_id\"],\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"title\":{\"type\":\"string\",\"pattern\":\"\\\\S\",\"description\":\"Wiki page title. When taken from a URL, percent-decode it first; Redmine stores spaces as underscores, so either form of a multi-word title works.\"},\"version\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"project_id\",\"title\"],\"additionalProperties\":false},\"create\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"title\":{\"type\":\"string\",\"pattern\":\"\\\\S\",\"description\":\"Wiki page title. When taken from a URL, percent-decode it first; Redmine stores spaces as underscores, so either form of a multi-word title works.\"},\"text\":{\"type\":\"string\",\"description\":\"Content of the page. Exactly one of `text` and `text_path` is required.\"},\"text_path\":{\"type\":\"string\",\"pattern\":\"\\\\S\",\"description\":\"Local file holding the `text` to send, as an alternative to `text` for a long text. The file must be UTF-8 and at most 1 MiB, is sent as is with its trailing newline but without a leading byte order mark, and cannot be combined with `text`. An absolute path is recommended, because a relative one resolves against the working directory of the server process.\"},\"comments\":{\"type\":\"string\"},\"parent_title\":{\"type\":\"string\"}},\"required\":[\"project_id\",\"title\"],\"additionalProperties\":false},\"update\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"title\":{\"type\":\"string\",\"pattern\":\"\\\\S\",\"description\":\"Wiki page title. When taken from a URL, percent-decode it first; Redmine stores spaces as underscores, so either form of a multi-word title works.\"},\"text\":{\"type\":\"string\",\"description\":\"Content of the page. Exactly one of `text` and `text_path` is required.\"},\"text_path\":{\"type\":\"string\",\"pattern\":\"\\\\S\",\"description\":\"Local file holding the `text` to send, as an alternative to `text` for a long text. The file must be UTF-8 and at most 1 MiB, is sent as is with its trailing newline but without a leading byte order mark, and cannot be combined with `text`. An absolute path is recommended, because a relative one resolves against the working directory of the server process.\"},\"comments\":{\"type\":\"string\"},\"version\":{\"type\":\"integer\",\"minimum\":1},\"parent_title\":{\"type\":\"string\"}},\"required\":[\"project_id\",\"title\"],\"additionalProperties\":false},\"delete\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"title\":{\"type\":\"string\",\"pattern\":\"\\\\S\",\"description\":\"Wiki page title. When taken from a URL, percent-decode it first; Redmine stores spaces as underscores, so either form of a multi-word title works.\"}},\"required\":[\"project_id\",\"title\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "tools/list advertises the wiki tool in readonly mode" {
  let listed = list_tools(wiki_tools(FakeWikiPages::new(), mode=Readonly))
  assert_eq(
    listed.stringify(),
    "{\"tools\":[{\"name\":\"redmine_wiki_pages\",\"description\":\"List and show Redmine wiki pages. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"}},\"required\":[\"project_id\"],\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"title\":{\"type\":\"string\",\"pattern\":\"\\\\S\",\"description\":\"Wiki page title. When taken from a URL, percent-decode it first; Redmine stores spaces as underscores, so either form of a multi-word title works.\"},\"version\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"project_id\",\"title\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "the wiki description names text_path only in full mode" {
  let full = list_tools(wiki_tools(FakeWikiPages::new())).stringify()
  assert_true(full.contains("`text_path`, the path of a local UTF-8 file"))
  let listed = list_tools(wiki_tools(FakeWikiPages::new(), mode=Readonly))
  assert_false(listed.stringify().contains("text_path"))
}
