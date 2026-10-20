///|
struct FakeVersions {
  calls : Array[String]
  created : Array[(String, @versions.Create)]
  updated : Array[(Int32, @versions.Update)]
  failure : @redmine.RedmineError?
}

///|
fn FakeVersions::new(failure? : @redmine.RedmineError) -> FakeVersions {
  { calls: [], created: [], updated: [], failure, }
}

///|
fn FakeVersions::record(
  self : FakeVersions,
  call : String,
) -> Unit raise @redmine.RedmineError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn fake_version(name : String) -> @versions.Version {
  {
    id: 7,
    project: { id: 1, name: "Demo", },
    name,
    description: None,
    status: Open,
    due_date: Some("2026-12-31"),
    sharing: None,
    wiki_page_title: None,
    created_on: "2026-01-01T00:00:00Z",
    updated_on: "2026-01-02T00:00:00Z",
  }
}

///|
fn version_project_label(project : @redmine.ProjectRef) -> String {
  match project {
    Id(id) => id.to_string()
    Identifier(name) => name
  }
}

///|
impl VersionPort for FakeVersions with fn list_versions(self, project) {
  self.record("list \{version_project_label(project)}")
  [fake_version("v1")]
}

///|
impl VersionPort for FakeVersions with fn show_version(self, id) {
  self.record("show \{id}")
  fake_version("v1")
}

///|
impl VersionPort for FakeVersions with fn create_version(
  self,
  project,
  attributes,
) {
  self.record("create \{version_project_label(project)}")
  self.created.push((version_project_label(project), attributes))
  fake_version(attributes.name)
}

///|
impl VersionPort for FakeVersions with fn update_version(self, id, attributes) {
  self.record("update \{id}")
  self.updated.push((id, attributes))
}

///|
impl VersionPort for FakeVersions with fn delete_version(self, id) {
  self.record("delete \{id}")
}

///|
fn version_tools(fake : FakeVersions, mode~ : Mode = Full) -> Array[@mcp.Tool] {
  [versions_tool(fake, mode)]
}

///|
async test "list and show reach their port methods" {
  let fake = FakeVersions::new()
  let tools = version_tools(fake)
  let listed = call_tool(tools, "redmine_versions", {
    "list": { "project_id": "demo" },
  })
  assert_eq(listed.is_error, false)
  assert_eq(
    listed.text,
    "[{\"id\":7,\"project\":{\"id\":1,\"name\":\"Demo\"},\"name\":\"v1\",\"status\":\"open\",\"due_date\":\"2026-12-31\",\"sharing\":\"none\",\"created_on\":\"2026-01-01T00:00:00Z\",\"updated_on\":\"2026-01-02T00:00:00Z\"}]",
  )
  let shown = call_tool(tools, "redmine_versions", { "show": { "id": 7 } })
  assert_true(shown.text.contains("\"name\":\"v1\""))
  assert_eq(fake.calls, ["list demo", "show 7"])
}

///|
async test "create maps every argument and answers the created version" {
  let fake = FakeVersions::new()
  let called = call_tool(version_tools(fake), "redmine_versions", {
    "create": {
      "project_id": 1,
      "name": "Sprint",
      "description": "d",
      "status": "locked",
      "due_date": "2026-12-31",
      "sharing": "tree",
      "wiki_page_title": "Sprint plan",
    },
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"name\":\"Sprint\""))
  assert_eq(fake.created, [
    (
      "1",
      {
        name: "Sprint",
        description: Some("d"),
        status: Some(Locked),
        due_date: Some("2026-12-31"),
        sharing: Some(Tree),
        wiki_page_title: Some("Sprint plan"),
      },
    ),
  ])
}

///|
async test "create with only a name leaves the rest unset" {
  let fake = FakeVersions::new()
  ignore(
    call_tool(version_tools(fake), "redmine_versions", {
      "create": { "project_id": "demo", "name": "Sprint" },
    }),
  )
  assert_eq(fake.created, [
    (
      "demo",
      {
        name: "Sprint",
        description: None,
        status: None,
        due_date: None,
        sharing: None,
        wiki_page_title: None,
      },
    ),
  ])
}

///|
async test "update maps the supplied arguments and answers ok" {
  let fake = FakeVersions::new()
  let tools = version_tools(fake)
  let called = call_tool(tools, "redmine_versions", {
    "update": {
      "id": 7,
      "name": "Renamed",
      "status": "closed",
      "sharing": "system",
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"ok\":true}")
  assert_eq(fake.updated, [
    (
      7,
      {
        name: Some("Renamed"),
        description: None,
        status: Some(Closed),
        due_date: None,
        sharing: Some(System),
        wiki_page_title: None,
      },
    ),
  ])
}

///|
async test "delete answers ok" {
  let fake = FakeVersions::new()
  let called = call_tool(version_tools(fake), "redmine_versions", {
    "delete": { "id": 7 },
  })
  assert_eq(called.text, "{\"ok\":true}")
  assert_eq(fake.calls, ["delete 7"])
}

///|
async test "validation reports the exact message for each rule" {
  let tools = version_tools(FakeVersions::new())
  let cases : Array[(Json, String)] = [
    (
      { "create": { "project_id": 1 } },
      "invalid arguments: create.name: is required",
    ),
    (
      { "create": { "project_id": 1, "name": "n", "status": "done" } },
      "invalid arguments: create.status: must be one of open, locked, closed",
    ),
    (
      { "create": { "project_id": 1, "name": "n", "sharing": "all" } },
      "invalid arguments: create.sharing: must be one of none, descendants, hierarchy, tree, system",
    ),
    (
      { "create": { "project_id": 1, "name": "n", "due_date": "2026-02-30" } },
      "invalid arguments: create.due_date: must be a date in the form YYYY-MM-DD",
    ),
    (
      { "update": { "id": 0 } },
      "invalid arguments: update.id: must be at least 1",
    ),
    (
      { "show": { "id": 1, "name": "x" } },
      "invalid arguments: show.name: unknown field",
    ),
    (
      { "list": { "project_id": "a b" } },
      "invalid arguments: list.project_id: no alternative matched: expected an integer; must not contain whitespace",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "redmine_versions", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
}

///|
async test "readonly mode makes the write actions unknown" {
  let fake = FakeVersions::new()
  let called = call_tool(
    version_tools(fake, mode=Readonly),
    "redmine_versions",
    { "delete": { "id": 7 } },
  )
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `delete`, one of: list, show\"]}",
  )
  assert_eq(fake.calls, [])
}

///|
async test "a Redmine failure becomes a failure payload" {
  let tools = version_tools(
    FakeVersions::new(failure=Response(status=404, errors=["Not Found"])),
  )
  let requests : Array[Json] = [
    { "show": { "id": 7 } },
    { "delete": { "id": 7 } },
  ]
  for arguments in requests {
    let called = call_tool(tools, "redmine_versions", arguments)
    assert_eq(called.is_error, true)
    assert_eq(called.text, "{\"status\":404,\"errors\":[\"Not Found\"]}")
  }
}

///|
async test "tools/list advertises the versions tool in full mode" {
  let listed = list_tools(version_tools(FakeVersions::new()))
  assert_eq(
    listed.stringify(),
    "{\"tools\":[{\"name\":\"redmine_versions\",\"description\":\"Create, read, update, and delete Redmine project versions (milestones). Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"}},\"required\":[\"project_id\"],\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false},\"create\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"name\":{\"type\":\"string\"},\"description\":{\"type\":\"string\"},\"status\":{\"type\":\"string\",\"enum\":[\"open\",\"locked\",\"closed\"]},\"due_date\":{\"type\":\"string\",\"format\":\"date\"},\"sharing\":{\"type\":\"string\",\"enum\":[\"none\",\"descendants\",\"hierarchy\",\"tree\",\"system\"]},\"wiki_page_title\":{\"type\":\"string\"}},\"required\":[\"project_id\",\"name\"],\"additionalProperties\":false},\"update\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1},\"name\":{\"type\":\"string\"},\"description\":{\"type\":\"string\"},\"status\":{\"type\":\"string\",\"enum\":[\"open\",\"locked\",\"closed\"]},\"due_date\":{\"type\":\"string\",\"format\":\"date\"},\"sharing\":{\"type\":\"string\",\"enum\":[\"none\",\"descendants\",\"hierarchy\",\"tree\",\"system\"]},\"wiki_page_title\":{\"type\":\"string\"}},\"required\":[\"id\"],\"additionalProperties\":false},\"delete\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "tools/list advertises the versions tool in readonly mode" {
  let listed = list_tools(version_tools(FakeVersions::new(), mode=Readonly))
  assert_eq(
    listed.stringify(),
    "{\"tools\":[{\"name\":\"redmine_versions\",\"description\":\"List and show Redmine project versions (milestones). Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"}},\"required\":[\"project_id\"],\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}
