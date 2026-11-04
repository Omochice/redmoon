///|
/// The tools `server` lists, so that a test reads the registration `serve` performs rather than a hand-built array.
async fn list_tools(server : @mcp.Server) -> Array[Json] {
  let responses = exchange(server, [
    { "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {} },
  ])
  guard responses is [_, { "result": { "tools": Array(tools), .. }, .. }, ..] else {
    fail("unexpected responses \{Json::array(responses).stringify()}")
  }
  tools
}

///|
fn operations_of(tools : Array[Json], name : String) -> Array[String] raise {
  guard tools.search_by(tool => tool is { "name": String(n), .. } && n == name)
    is Some(index) else {
    fail("\{name} is not registered")
  }
  guard tools[index]
    is { "inputSchema": { "properties": Object(operations), .. }, .. } else {
    fail("\{name} has no keyed schema")
  }
  operations.keys().collect()
}

///|
async test "build_server lists every plugin tool and the write actions in full mode" {
  let redmine = @livetest.redmine()
  let tools = list_tools(
    @cli.build_server(redmine, false, [
      @cli.IssueTemplates,
      @cli.Agile,
      @cli.AdditionalTags,
    ]),
  )
  let names = tools.map(tool => {
    match tool {
      { "name": String(name), .. } => name
      _ => ""
    }
  })
  for name in ["redmine_issue_templates", "redmine_agile", "redmine_tags"] {
    assert_true(names.contains(name), msg="\{name} is not listed")
  }
  assert_true(operations_of(tools, "redmine_issues").contains("create"))
  assert_true(operations_of(tools, "redmine_tags").contains("add"))
}

///|
async test "a plugin tool answers through build_server" {
  let redmine = @livetest.redmine()
  let called = call(
    @cli.build_server(redmine, true, [@cli.IssueTemplates]),
    "redmine_issue_templates",
    { "list": { "project_id": "demo", "tracker_id": 1 } },
  )
  assert_eq(called.is_error, false, msg=called.text)
  assert_true(called.text.contains("\"title\":\"Bug report\""))
}

///|
async test "a write action reaches Redmine through build_server in full mode" {
  let redmine = @livetest.redmine()
  let subject = "redmoon-build-server-\{@env.now()}"
  let created = call(@cli.build_server(redmine, false, []), "redmine_issues", {
    "create": {
      "project_id": 1,
      "tracker_id": 1,
      "status_id": 1,
      "priority_id": 2,
      "subject": subject,
    },
  })
  assert_eq(created.is_error, false, msg=created.text)
  guard @json.parse(created.text) is { "id": Number(id, ..), .. } else {
    fail("no id in \{created.text}")
  }
  let id = id.to_int()
  defer @livetest.delete_probe_issue(redmine, id)
  let shown = call(@cli.build_server(redmine, false, []), "redmine_issues", {
    "show": { "id": id },
  })
  assert_true(shown.text.contains(subject))
}
