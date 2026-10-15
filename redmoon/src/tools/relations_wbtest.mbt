///|
struct FakeRelations {
  failure : @redmine.RedmineError?
  creates : Array[(Int32, Int32, @redmine.RelationType, Int32?)]
  deletes : Array[Int32]
}

///|
fn fake_relation(
  id : Int32,
  issue_id : Int32,
  issue_to_id : Int32,
  relation_type : @redmine.RelationType,
  delay : Int32?,
) -> @redmine.Relation {
  { id, issue_id, issue_to_id, relation_type, delay, }
}

///|
fn FakeRelations::check(
  self : FakeRelations,
) -> Unit raise @redmine.RedmineError {
  if self.failure is Some(error) {
    raise error
  }
}

///|
impl RelationPort for FakeRelations with fn list_relations(self, issue_id) {
  self.check()
  [fake_relation(7, issue_id, 2, Blocks, None)]
}

///|
impl RelationPort for FakeRelations with fn show_relation(self, id) {
  self.check()
  fake_relation(id, 1, 2, Relates, None)
}

///|
impl RelationPort for FakeRelations with fn create_relation(
  self,
  issue_id,
  issue_to_id,
  relation_type,
  delay,
) {
  self.check()
  self.creates.push((issue_id, issue_to_id, relation_type, delay))
  fake_relation(100, issue_id, issue_to_id, relation_type, delay)
}

///|
impl RelationPort for FakeRelations with fn delete_relation(self, id) {
  self.check()
  self.deletes.push(id)
}

///|
fn fake_relations(failure? : @redmine.RedmineError) -> FakeRelations {
  FakeRelations::{ failure, creates: [], deletes: [], }
}

///|
async test "list answers the relations of the issue as a bare array" {
  let called = call_tool(
    [relations_tool(fake_relations(), Full)],
    "redmine_issue_relations",
    { "list": { "issue_id": 1 } },
  )
  assert_eq(called.is_error, false)
  assert_eq(
    called.text,
    "[{\"id\":7,\"issue_id\":1,\"issue_to_id\":2,\"relation_type\":\"blocks\"}]",
  )
}

///|
async test "show passes the relation id to the port" {
  let called = call_tool(
    [relations_tool(fake_relations(), Full)],
    "redmine_issue_relations",
    { "show": { "id": 42 } },
  )
  assert_eq(called.is_error, false)
  assert_eq(
    called.text,
    "{\"id\":42,\"issue_id\":1,\"issue_to_id\":2,\"relation_type\":\"relates\"}",
  )
}

///|
async test "a Redmine failure becomes a failure payload" {
  let tools = [
    relations_tool(
      fake_relations(failure=Response(status=403, errors=["Forbidden"])),
      Full,
    ),
  ]
  let called = call_tool(tools, "redmine_issue_relations", {
    "list": { "issue_id": 1 },
  })
  assert_eq(called.is_error, true)
  assert_eq(called.text, "{\"status\":403,\"errors\":[\"Forbidden\"]}")
}

///|
async test "a non-positive issue id is reported with its action path" {
  let called = call_tool(
    [relations_tool(fake_relations(), Full)],
    "redmine_issue_relations",
    { "list": { "issue_id": 0 } },
  )
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: list.issue_id: must be at least 1\"]}",
  )
}

///|
async test "a stray argument is reported with its action path" {
  let called = call_tool(
    [relations_tool(fake_relations(), Full)],
    "redmine_issue_relations",
    { "show": { "id": 1, "x": 1 } },
  )
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: show.x: unknown field\"]}",
  )
}

///|
async test "create maps every argument to the port, delay included" {
  let fake = fake_relations()
  let called = call_tool(
    [relations_tool(fake, Full)],
    "redmine_issue_relations",
    {
      "create": {
        "issue_id": 1,
        "issue_to_id": 2,
        "relation_type": "blocks",
        "delay": 3,
      },
    },
  )
  assert_eq(called.is_error, false)
  assert_eq(fake.creates, [(1, 2, Blocks, Some(3))])
  assert_eq(
    called.text,
    "{\"id\":100,\"issue_id\":1,\"issue_to_id\":2,\"relation_type\":\"blocks\",\"delay\":3}",
  )
}

///|
async test "create without a delay passes none to the port" {
  let fake = fake_relations()
  let called = call_tool(
    [relations_tool(fake, Full)],
    "redmine_issue_relations",
    {
      "create": {
        "issue_id": 5,
        "issue_to_id": 6,
        "relation_type": "copied_from",
      },
    },
  )
  assert_eq(called.is_error, false)
  assert_eq(fake.creates, [(5, 6, CopiedFrom, None)])
}

///|
async test "every relation type name reaches its SDK value" {
  let names : Array[(String, @redmine.RelationType)] = [
    ("relates", Relates),
    ("duplicates", Duplicates),
    ("duplicated", Duplicated),
    ("blocks", Blocks),
    ("blocked", Blocked),
    ("precedes", Precedes),
    ("follows", Follows),
    ("copied_to", CopiedTo),
    ("copied_from", CopiedFrom),
  ]
  let fake = fake_relations()
  let tools = [relations_tool(fake, Full)]
  for name in names {
    ignore(
      call_tool(tools, "redmine_issue_relations", {
        "create": { "issue_id": 1, "issue_to_id": 2, "relation_type": name.0 },
      }),
    )
  }
  assert_eq(fake.creates.map(c => c.2), names.map(n => n.1))
}

///|
async test "an unknown relation type is rejected with the allowed names" {
  let called = call_tool(
    [relations_tool(fake_relations(), Full)],
    "redmine_issue_relations",
    {
      "create": { "issue_id": 1, "issue_to_id": 2, "relation_type": "related" },
    },
  )
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: create.relation_type: must be one of relates, duplicates, duplicated, blocks, blocked, precedes, follows, copied_to, copied_from\"]}",
  )
}

///|
async test "delete passes the relation id to the port and answers ok" {
  let fake = fake_relations()
  let called = call_tool(
    [relations_tool(fake, Full)],
    "redmine_issue_relations",
    { "delete": { "id": 7 } },
  )
  assert_eq(called.is_error, false)
  assert_eq(fake.deletes, [7])
  assert_eq(called.text, "{\"ok\":true}")
}

///|
async test "readonly refuses a create as an unknown action" {
  let called = call_tool(
    [relations_tool(fake_relations(), Readonly)],
    "redmine_issue_relations",
    { "create": { "issue_id": 1, "issue_to_id": 2, "relation_type": "blocks" } },
  )
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `create`, one of: list, show\"]}",
  )
}

///|
async test "tools/list advertises the write actions only in full mode" {
  let advertised_full = list_tools([relations_tool(fake_relations(), Full)]).stringify()
  let advertised_read_only = list_tools([
    relations_tool(fake_relations(), Readonly),
  ]).stringify()
  assert_eq(
    advertised_full, "{\"tools\":[{\"name\":\"redmine_issue_relations\",\"description\":\"Create, read, and delete Redmine issue relations. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"issue_id\"],\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false},\"create\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1},\"issue_to_id\":{\"type\":\"integer\",\"minimum\":1},\"relation_type\":{\"type\":\"string\",\"enum\":[\"relates\",\"duplicates\",\"duplicated\",\"blocks\",\"blocked\",\"precedes\",\"follows\",\"copied_to\",\"copied_from\"]},\"delay\":{\"type\":\"integer\"}},\"required\":[\"issue_id\",\"issue_to_id\",\"relation_type\"],\"additionalProperties\":false},\"delete\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
  assert_eq(
    advertised_read_only, "{\"tools\":[{\"name\":\"redmine_issue_relations\",\"description\":\"List and show Redmine issue relations. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"issue_id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"issue_id\"],\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "live: a relation is created, listed, shown and deleted through the tool" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = @redmine.Redmine::new(endpoint~, api_key~)
  let subject = "redmoon-relations-\{@env.now()}"
  let first = redmine.create_issue(
    @redmine.IssueCreate::new(
      project_id=1,
      tracker_id=1,
      status_id=1,
      priority_id=2,
      subject="\{subject}-a",
    ),
  )
  let second = redmine.create_issue(
    @redmine.IssueCreate::new(
      project_id=1,
      tracker_id=1,
      status_id=1,
      priority_id=2,
      subject="\{subject}-b",
    ),
  )
  let tools = [relations_tool(redmine, Full)]
  let outcome : Error? = try {
    exercise_relation(tools, first.id, second.id)
    None
  } catch {
    error => Some(error)
  }
  redmine.delete_issue(first.id)
  redmine.delete_issue(second.id)
  if outcome is Some(error) {
    raise error
  }
}

///|
async fn exercise_relation(
  tools : Array[@mcp.Tool],
  from : Int32,
  to : Int32,
) -> Unit {
  let created = call_tool(tools, "redmine_issue_relations", {
    "create": { "issue_id": from, "issue_to_id": to, "relation_type": "blocks" },
  })
  assert_eq(created.is_error, false)
  let relation_id = match @json.parse(created.text) {
    { "id": Number(id, ..), .. } => id.to_int()
    _ => fail("the created relation has no id: \{created.text}")
  }
  let listed = call_tool(tools, "redmine_issue_relations", {
    "list": { "issue_id": from },
  })
  assert_true(listed.text.contains("\"issue_to_id\":\{to}"))
  let shown = call_tool(tools, "redmine_issue_relations", {
    "show": { "id": relation_id },
  })
  assert_true(shown.text.contains("\"relation_type\":\"blocks\""))
  let deleted = call_tool(tools, "redmine_issue_relations", {
    "delete": { "id": relation_id },
  })
  assert_eq(deleted.text, "{\"ok\":true}")
}
