///|
async fn exchange(server : @mcp.Server, requests : Array[Json]) -> Array[Json] {
  let (in_read, in_write) = @io.pipe()
  let (out_read, out_write) = @io.pipe()
  let output = @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      defer out_write.close()
      server.serve(in_read, out_write)
    })
    let collected = group.spawn(async fn() { out_read.read_all().text() })
    {
      defer in_write.close()
      let initialize : Json = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": { "protocolVersion": "2025-11-25", "capabilities": {} },
      }
      in_write.write(initialize.stringify() + "\n")
      for request in requests {
        in_write.write(request.stringify() + "\n")
      }
    }
    collected.wait()
  })
  let responses = []
  for line in output.split("\n") {
    if line.length() > 0 {
      responses.push(@json.parse(line.to_owned()))
    }
  }
  responses
}

///|
fn request(id : Int32, rpc_method : String, params : Json) -> Json {
  { "jsonrpc": "2.0", "id": id, "method": rpc_method, "params": params }
}

///|
async test "the server lists the registered tools" {
  let redmine = @redmine.new(endpoint="http://localhost:3000", api_key="unused")
  let responses = exchange(build_server(redmine, false, []), [
    request(2, "tools/list", {}),
  ])
  guard responses[1] is { "result": { "tools": Array(tools), .. }, .. } else {
    fail("no tools/list result")
  }
  let names = tools.map(tool => {
    match tool {
      { "name": String(name), .. } => name
      _ => ""
    }
  })
  assert_true(names.contains("redmine_enumerations"))
  assert_false(names.contains("redmine_issue_templates"))
  assert_false(names.contains("redmine_agile"))
  assert_true(names.contains("redmoon_info"))
}

///|
async test "the memberships tool is listed in both modes" {
  let redmine = @redmine.new(endpoint="http://localhost:3000", api_key="unused")
  for read_only in [false, true] {
    let responses = exchange(build_server(redmine, read_only, []), [
      request(2, "tools/list", {}),
    ])
    assert_true(
      responses[1].stringify().contains("\"name\":\"redmine_memberships\""),
    )
  }
}

///|
async test "the issue templates plugin adds its tool in both modes" {
  let redmine = @redmine.new(endpoint="http://localhost:3000", api_key="unused")
  for read_only in [false, true] {
    let responses = exchange(
      build_server(redmine, read_only, [IssueTemplates]),
      [request(2, "tools/list", {})],
    )
    assert_true(
      responses[1].stringify().contains("\"name\":\"redmine_issue_templates\""),
    )
  }
}

///|
async test "the agile plugin adds its tool, without update in readonly mode" {
  let redmine = @redmine.new(endpoint="http://localhost:3000", api_key="unused")
  for read_only in [false, true] {
    let responses = exchange(build_server(redmine, read_only, [Agile]), [
      request(2, "tools/list", {}),
    ])
    guard responses[1] is { "result": { "tools": Array(tools), .. }, .. } else {
      fail("no tools/list result")
    }
    guard tools.search_by(tool => tool is { "name": "redmine_agile", .. })
      is Some(index) else {
      fail("redmine_agile is not registered")
    }
    guard tools[index]
      is { "inputSchema": { "properties": Object(actions), .. }, .. } else {
      fail("redmine_agile has no keyed schema")
    }
    assert_true(actions.contains("get"))
    assert_eq(actions.contains("update"), !read_only)
  }
}
