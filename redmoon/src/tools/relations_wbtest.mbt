///|
struct FakeRelations {
  failure : @redmine.RedmineError?
  creates : Array[(Int32, Int32, @relations.Type, Int32?)]
  deletes : Array[Int32]
}

///|
fn fake_relation(
  id : Int32,
  issue_id : Int32,
  issue_to_id : Int32,
  relation_type : @relations.Type,
  delay : Int32?,
) -> @relations.Relation {
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
  let names : Array[(String, @relations.Type)] = [
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
