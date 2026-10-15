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
async test "live: a relation is listed and shown through the tool" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = @redmine.Redmine::new(endpoint~, api_key~)
  let offline = @redmine.Redmine::new(endpoint="http://127.0.0.1:1", api_key~)
  let denied = call_tool(
    [relations_tool(offline, Full)],
    "redmine_issue_relations",
    { "list": { "issue_id": 1 } },
  )
  assert_eq(denied.is_error, true)
  assert_true(denied.text.contains("\"status\":0"))
  let called = call_tool(
    [relations_tool(redmine, Full)],
    "redmine_issue_relations",
    { "list": { "issue_id": 1 } },
  )
  assert_eq(called.is_error, false)
}
