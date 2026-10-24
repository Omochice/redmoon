///|
struct FakeAgile {
  calls : Array[String]
  updated : Array[(Int32, @agile.Update)]
  failure : @redmine.RedmineError?
}

///|
fn FakeAgile::new(failure? : @redmine.RedmineError) -> FakeAgile {
  { calls: [], updated: [], failure, }
}

///|
fn FakeAgile::record(
  self : FakeAgile,
  call : String,
) -> Unit raise @redmine.RedmineError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
impl AgilePort for FakeAgile with fn get_agile_data(self, issue_id) {
  self.record("get \{issue_id}")
  {
    id: 9,
    issue_id,
    story_points: Some(3),
    agile_sprint_id: None,
    position: Some(2),
  }
}

///|
impl AgilePort for FakeAgile with fn update_agile_data(
  self,
  issue_id,
  attributes,
) {
  self.record("update \{issue_id}")
  self.updated.push((issue_id, attributes))
}

///|
fn agile_tools(fake : FakeAgile, mode~ : Mode = Full) -> Array[@mcp.Tool] {
  [agile_tool(fake, mode)]
}

///|
async test "get reaches the port and answers the agile data" {
  let fake = FakeAgile::new()
  let called = call_tool(agile_tools(fake), "redmine_agile", {
    "get": { "issue_id": 42 },
  })
  assert_eq(called.is_error, false)
  assert_eq(
    called.text,
    "{\"id\":9,\"issue_id\":42,\"story_points\":3,\"position\":2}",
  )
  assert_eq(fake.calls, ["get 42"])
}

///|
async test "update sets the given fields, clears the null ones, and leaves the rest alone" {
  let fake = FakeAgile::new()
  let called = call_tool(agile_tools(fake), "redmine_agile", {
    "update": { "issue_id": 42, "story_points": 5, "agile_sprint_id": null },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"ok\":true}")
  assert_eq(fake.updated, [
    (
      42,
      {
        story_points: Some(Set(5)),
        agile_sprint_id: Some(Clear),
        position: None,
      },
    ),
  ])
  ignore(
    call_tool(agile_tools(fake), "redmine_agile", {
      "update": { "issue_id": 7, "agile_sprint_id": 3, "position": 1 },
    }),
  )
  assert_eq(
    fake.updated[1],
    (
      7,
      {
        story_points: None,
        agile_sprint_id: Some(Set(3)),
        position: Some(Set(1)),
      },
    ),
  )
}

///|
async test "validation reports the exact message for each rule" {
  let tools = agile_tools(FakeAgile::new())
  let cases : Array[(Json, String)] = [
    ({ "get": {} }, "invalid arguments: get.issue_id: is required"),
    (
      { "update": { "issue_id": 0 } },
      "invalid arguments: update.issue_id: must be at least 1",
    ),
    (
      { "update": { "issue_id": 1, "story_points": -1 } },
      "invalid arguments: update.story_points: must be at least 0",
    ),
    (
      { "update": { "issue_id": 1, "agile_sprint_id": 0 } },
      "invalid arguments: update.agile_sprint_id: must be at least 1",
    ),
    (
      { "update": { "issue_id": 1, "agile_position": 1 } },
      "invalid arguments: update.agile_position: unknown field",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "redmine_agile", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
}

///|
async test "readonly mode makes update unknown" {
  let fake = FakeAgile::new()
  let called = call_tool(agile_tools(fake, mode=Readonly), "redmine_agile", {
    "update": { "issue_id": 42, "story_points": 5 },
  })
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `update`, one of: get\"]}",
  )
  assert_eq(fake.calls, [])
}

///|
async test "a missing plugin, module, or row becomes a failure payload" {
  for status in [403, 404] {
    let tools = agile_tools(
      FakeAgile::new(failure=Response(status~, errors=[])),
    )
    let requests : Array[Json] = [
      { "get": { "issue_id": 42 } },
      { "update": { "issue_id": 42, "story_points": 5 } },
    ]
    for arguments in requests {
      let called = call_tool(tools, "redmine_agile", arguments)
      assert_eq(called.is_error, true)
      assert_eq(called.text, "{\"status\":\{status},\"errors\":[]}")
    }
  }
}

///|
async test "tools/list advertises the agile tool in full mode" {
  let listed = list_tools(agile_tools(FakeAgile::new()))
  assert_eq(
    listed.stringify(),
    "{\"tools\":[{\"name\":\"redmine_agile\",\"description\":\"Read and change the RedmineUP Agile data of one Redmine issue: its story points, its sprint, and the position of its card on the agile board.\\n`update` changes only the fields it is given and keeps the others; `null` clears a field, which for `agile_sprint_id` takes the issue out of its sprint.\\nA sprint is named by its id, which `get` shows as `agile_sprint_id` on an issue already in that sprint.\\nNeeds the RedmineUP Agile plugin and the Agile module enabled on the issue's project: Redmine answers 404 for an issue without agile data and where the plugin is missing, and 403 where the module or the permission is missing.\\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"get\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"issue_id\"],\"additionalProperties\":false},\"update\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1},\"story_points\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":0},{\"type\":\"null\"}],\"description\":\"Estimate in story points, a whole number; `null` clears it.\"},\"agile_sprint_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"null\"}],\"description\":\"Sprint to put the issue in; `null` takes it out of its sprint.\"},\"position\":{\"anyOf\":[{\"type\":\"integer\"},{\"type\":\"null\"}],\"description\":\"Sort position of the issue's card on the agile board; `null` clears it.\"}},\"required\":[\"issue_id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "tools/list advertises the agile tool in readonly mode without update" {
  let listed = list_tools(agile_tools(FakeAgile::new(), mode=Readonly))
  assert_eq(
    listed.stringify(),
    "{\"tools\":[{\"name\":\"redmine_agile\",\"description\":\"Read the RedmineUP Agile data of one Redmine issue: its story points, its sprint, and the position of its card on the agile board.\\nNeeds the RedmineUP Agile plugin and the Agile module enabled on the issue's project: Redmine answers 404 for an issue without agile data and where the plugin is missing, and 403 where the module or the permission is missing.\\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"get\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"issue_id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}
