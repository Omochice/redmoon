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
impl VersionPort for FakeVersions with fn list_versions(self, project) {
  self.record("list \{project_label(project)}")
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
  self.record("create \{project_label(project)}")
  self.created.push((project_label(project), attributes))
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
fn versions_tools(fake : FakeVersions, mode~ : Mode = Full) -> Array[@mcp.Tool] {
  [versions_tool(fake, mode)]
}

///|
async test "list and show reach their port methods" {
  let fake = FakeVersions::new()
  let tools = versions_tools(fake)
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
  let called = call_tool(versions_tools(fake), "redmine_versions", {
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
      @versions.Create::new(
        name="Sprint",
        description="d",
        status=Locked,
        due_date="2026-12-31",
        sharing=Tree,
        wiki_page_title="Sprint plan",
      ),
    ),
  ])
}

///|
async test "create with only a name leaves the rest unset" {
  let fake = FakeVersions::new()
  ignore(
    call_tool(versions_tools(fake), "redmine_versions", {
      "create": { "project_id": "demo", "name": "Sprint" },
    }),
  )
  assert_eq(fake.created, [("demo", @versions.Create::new(name="Sprint"))])
}

///|
async test "update maps the supplied arguments and answers ok" {
  let fake = FakeVersions::new()
  let tools = versions_tools(fake)
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
    (7, @versions.Update::new(name="Renamed", status=Closed, sharing=System)),
  ])
}

///|
async test "versions: delete answers ok" {
  let fake = FakeVersions::new()
  let called = call_tool(versions_tools(fake), "redmine_versions", {
    "delete": { "id": 7 },
  })
  assert_eq(called.text, "{\"ok\":true}")
  assert_eq(fake.calls, ["delete 7"])
}

///|
async test "versions: validation reports the exact message for each rule" {
  let tools = versions_tools(FakeVersions::new())
  let cases : Array[(Json, String)] = [
    (
      { "create": { "project_id": 1 } },
      "invalid arguments: create.name: is required",
    ),
    (
      { "create": { "project_id": 1, "name": "n", "status": "done" } },
      "invalid arguments: create.status: must be one of `open`, `locked` and `closed`",
    ),
    (
      { "create": { "project_id": 1, "name": "n", "sharing": "all" } },
      "invalid arguments: create.sharing: must be one of `none`, `descendants`, `hierarchy`, `tree` and `system`",
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
async test "versions: readonly mode makes the write actions unknown" {
  let fake = FakeVersions::new()
  let called = call_tool(
    versions_tools(fake, mode=Readonly),
    "redmine_versions",
    { "delete": { "id": 7 } },
  )
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `delete`, one of `list` and `show`\"]}",
  )
  assert_eq(fake.calls, [])
}

///|
async test "versions: a Redmine failure becomes a failure payload" {
  let tools = versions_tools(
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

///|
async fn rejected_version(arguments : Json) -> String {
  let fake = FakeVersions::new()
  let called = call_tool(versions_tools(fake), "redmine_versions", arguments)
  assert_eq(called.is_error, true, msg="accepted \{arguments.stringify()}")
  assert_eq(fake.calls, [])
  called.text
}

///|
async test "a blank name is rejected on create and update" {
  assert_eq(
    rejected_version({ "create": { "project_id": 1, "name": " " } }),
    "{\"status\":0,\"errors\":[\"invalid arguments: create.name: must not be blank\"]}",
  )
  assert_eq(
    rejected_version({ "update": { "id": 7, "name": " " } }),
    "{\"status\":0,\"errors\":[\"invalid arguments: update.name: must not be blank\"]}",
  )
}

///|
async test "a name over 60 characters is rejected on create and update, as Redmine limits it" {
  let long = String::make(61, 'a')
  assert_eq(
    rejected_version({ "create": { "project_id": 1, "name": long } }),
    "{\"status\":0,\"errors\":[\"invalid arguments: create.name: must be at most 60 characters\"]}",
  )
  assert_eq(
    rejected_version({ "update": { "id": 7, "name": long } }),
    "{\"status\":0,\"errors\":[\"invalid arguments: update.name: must be at most 60 characters\"]}",
  )
}

///|
async test "a name of exactly 60 characters is accepted on create and update" {
  let fake = FakeVersions::new()
  let tools = versions_tools(fake)
  let name = String::make(60, 'a')
  let created = call_tool(tools, "redmine_versions", {
    "create": { "project_id": 1, "name": name },
  })
  assert_eq(created.is_error, false, msg=created.text)
  assert_eq(fake.created[0].1.name, name)
  let updated = call_tool(tools, "redmine_versions", {
    "update": { "id": 7, "name": name },
  })
  assert_eq(updated.is_error, false, msg=updated.text)
  assert_eq(fake.updated[0].1.name, Some(name))
}

///|
async test "a description over 255 characters is rejected on create and update" {
  let long = String::make(256, 'a')
  assert_eq(
    rejected_version({
      "create": { "project_id": 1, "name": "n", "description": long },
    }),
    "{\"status\":0,\"errors\":[\"invalid arguments: create.description: must be at most 255 characters\"]}",
  )
  assert_eq(
    rejected_version({ "update": { "id": 7, "description": long } }),
    "{\"status\":0,\"errors\":[\"invalid arguments: update.description: must be at most 255 characters\"]}",
  )
}

///|
async test "a description of exactly 255 characters is accepted on create and update" {
  let fake = FakeVersions::new()
  let tools = versions_tools(fake)
  let description = String::make(255, 'a')
  let created = call_tool(tools, "redmine_versions", {
    "create": { "project_id": 1, "name": "n", "description": description },
  })
  assert_eq(created.is_error, false, msg=created.text)
  assert_eq(fake.created[0].1.description, Some(description))
  let updated = call_tool(tools, "redmine_versions", {
    "update": { "id": 7, "description": description },
  })
  assert_eq(updated.is_error, false, msg=updated.text)
  assert_eq(fake.updated[0].1.description, Some(Set(description)))
}

///|
async test "a wiki_page_title over 255 characters is rejected on create and update" {
  let long = String::make(256, 'a')
  assert_eq(
    rejected_version({
      "create": { "project_id": 1, "name": "n", "wiki_page_title": long },
    }),
    "{\"status\":0,\"errors\":[\"invalid arguments: create.wiki_page_title: must be at most 255 characters\"]}",
  )
  assert_eq(
    rejected_version({ "update": { "id": 7, "wiki_page_title": long } }),
    "{\"status\":0,\"errors\":[\"invalid arguments: update.wiki_page_title: must be at most 255 characters\"]}",
  )
}

///|
async test "a wiki_page_title of exactly 255 characters is accepted on create and update" {
  let fake = FakeVersions::new()
  let tools = versions_tools(fake)
  let title = String::make(255, 'a')
  let created = call_tool(tools, "redmine_versions", {
    "create": { "project_id": 1, "name": "n", "wiki_page_title": title },
  })
  assert_eq(created.is_error, false, msg=created.text)
  assert_eq(fake.created[0].1.wiki_page_title, Some(title))
  let updated = call_tool(tools, "redmine_versions", {
    "update": { "id": 7, "wiki_page_title": title },
  })
  assert_eq(updated.is_error, false, msg=updated.text)
  assert_eq(fake.updated[0].1.wiki_page_title, Some(Set(title)))
}

///|
async test "tools/list advertises the versions tool in full mode" {
  let listed = list_tools(versions_tools(FakeVersions::new()))
  inspect(
    listed.stringify(),
    content=(
      #|{"tools":[{"name":"redmine_versions","description":"Create, read, update, and delete Redmine project versions (milestones).\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.","inputSchema":{"type":"object","properties":{"list":{"type":"object","properties":{"project_id":{"anyOf":[{"type":"integer","minimum":1},{"type":"string","pattern":"^\\S+$"}],"description":"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...)."}},"required":["project_id"],"additionalProperties":false},"show":{"type":"object","properties":{"id":{"type":"integer","minimum":1}},"required":["id"],"additionalProperties":false},"create":{"type":"object","properties":{"project_id":{"anyOf":[{"type":"integer","minimum":1},{"type":"string","pattern":"^\\S+$"}],"description":"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...)."},"name":{"type":"string","maxLength":60,"pattern":"\\S","description":"Name of the version, unique within its project."},"description":{"type":"string","maxLength":255,"description":"Free text shown on the version's page."},"status":{"type":"string","enum":["open","locked","closed"],"description":"`open` accepts new issues, `locked` refuses them while keeping the version listed, and `closed` ends it."},"due_date":{"type":"string","format":"date","description":"Day the version is due, as an ISO date (`YYYY-MM-DD`)."},"sharing":{"type":"string","enum":["none","descendants","hierarchy","tree","system"],"description":"Which other projects can assign issues to the version: `none`, the project's `descendants`, its `hierarchy` (ancestors and descendants), its whole `tree`, or `system` for every project."},"wiki_page_title":{"type":"string","maxLength":255,"description":"Title of the wiki page in the same project that the version links to."}},"required":["project_id","name"],"additionalProperties":false},"update":{"type":"object","properties":{"id":{"type":"integer","minimum":1},"name":{"type":"string","maxLength":60,"pattern":"\\S","description":"Name of the version, unique within its project."},"description":{"type":"string","maxLength":255,"description":"Free text shown on the version's page."},"status":{"type":"string","enum":["open","locked","closed"],"description":"`open` accepts new issues, `locked` refuses them while keeping the version listed, and `closed` ends it."},"due_date":{"type":"string","format":"date","description":"Day the version is due, as an ISO date (`YYYY-MM-DD`)."},"sharing":{"type":"string","enum":["none","descendants","hierarchy","tree","system"],"description":"Which other projects can assign issues to the version: `none`, the project's `descendants`, its `hierarchy` (ancestors and descendants), its whole `tree`, or `system` for every project."},"wiki_page_title":{"type":"string","maxLength":255,"description":"Title of the wiki page in the same project that the version links to."}},"required":["id"],"additionalProperties":false},"delete":{"type":"object","properties":{"id":{"type":"integer","minimum":1}},"required":["id"],"additionalProperties":false}},"minProperties":1,"maxProperties":1,"additionalProperties":false}}]}
    ),
  )
}

///|
async test "tools/list advertises the versions tool in readonly mode" {
  let listed = list_tools(versions_tools(FakeVersions::new(), mode=Readonly))
  inspect(
    listed.stringify(),
    content=(
      #|{"tools":[{"name":"redmine_versions","description":"List and show Redmine project versions (milestones).\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.","inputSchema":{"type":"object","properties":{"list":{"type":"object","properties":{"project_id":{"anyOf":[{"type":"integer","minimum":1},{"type":"string","pattern":"^\\S+$"}],"description":"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...)."}},"required":["project_id"],"additionalProperties":false},"show":{"type":"object","properties":{"id":{"type":"integer","minimum":1}},"required":["id"],"additionalProperties":false}},"minProperties":1,"maxProperties":1,"additionalProperties":false}}]}
    ),
  )
}
