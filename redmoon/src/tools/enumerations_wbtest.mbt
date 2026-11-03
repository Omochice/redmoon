///|
struct FakeEnumerations {
  calls : Array[String]
  failure : @redmine.RedmineError?
}

///|
fn FakeEnumerations::new(failure? : @redmine.RedmineError) -> FakeEnumerations {
  { calls: [], failure, }
}

///|
fn FakeEnumerations::record(
  self : FakeEnumerations,
  call : String,
) -> Unit raise @redmine.RedmineError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn fake_enumeration(id : Int32, name : String) -> @enumerations.Enumeration {
  { id, name, is_default: id == 9, active: true, }
}

///|
impl EnumerationPort for FakeEnumerations with fn list_time_entry_activities(
  self,
) {
  self.record("list_time_entry_activities")
  [fake_enumeration(9, "Design"), fake_enumeration(10, "Development")]
}

///|
impl EnumerationPort for FakeEnumerations with fn list_issue_priorities(self) {
  self.record("list_issue_priorities")
  [fake_enumeration(1, "Low"), fake_enumeration(2, "Normal")]
}

///|
impl EnumerationPort for FakeEnumerations with fn list_document_categories(self) {
  self.record("list_document_categories")
  [fake_enumeration(3, "User documentation")]
}

///|
fn enumerations_tools(fake : FakeEnumerations) -> Array[@mcp.Tool] {
  [enumerations_tool(fake)]
}

///|
async test "each listing reaches its own port method" {
  let tools = enumerations_tools(FakeEnumerations::new())
  let activities = call_tool(tools, "redmine_enumerations", {
    "list_time_entry_activities": {},
  })
  assert_eq(activities.is_error, false)
  assert_eq(
    activities.text,
    "[{\"id\":9,\"name\":\"Design\",\"is_default\":true,\"active\":true},{\"id\":10,\"name\":\"Development\",\"is_default\":false,\"active\":true}]",
  )
  let priorities = call_tool(tools, "redmine_enumerations", {
    "list_issue_priorities": {},
  })
  assert_true(priorities.text.contains("\"name\":\"Normal\""))
  let categories = call_tool(tools, "redmine_enumerations", {
    "list_document_categories": {},
  })
  assert_true(categories.text.contains("User documentation"))
}

///|
async test "a Redmine failure becomes a failure payload" {
  let tools = enumerations_tools(
    FakeEnumerations::new(failure=Response(status=403, errors=["Forbidden"])),
  )
  let called = call_tool(tools, "redmine_enumerations", {
    "list_issue_priorities": {},
  })
  assert_eq(called.is_error, true)
  assert_eq(called.text, "{\"status\":403,\"errors\":[\"Forbidden\"]}")
}

///|
async test "an unknown action is reported with the invalid arguments wording" {
  let called = call_tool(
    enumerations_tools(FakeEnumerations::new()),
    "redmine_enumerations",
    { "list_nothing": {} },
  )
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `list_nothing`, one of `list_time_entry_activities`, `list_issue_priorities` and `list_document_categories`\"]}",
  )
}

///|
async test "a stray argument is reported with its action path" {
  let called = call_tool(
    enumerations_tools(FakeEnumerations::new()),
    "redmine_enumerations",
    { "list_issue_priorities": { "x": 1 } },
  )
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: list_issue_priorities.x: unknown field\"]}",
  )
}

///|
async test "tools/list advertises the enumerations tool" {
  let advertised = list_tools(enumerations_tools(FakeEnumerations::new())).stringify()
  inspect(
    advertised,
    content=(
      #|{"tools":[{"name":"redmine_enumerations","description":"Lists the Redmine enumerations that supply ids other tools require: time entry activities for `activity_id`, issue priorities for `priority_id`, and document categories.\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.","inputSchema":{"type":"object","properties":{"list_time_entry_activities":{"type":"object","properties":{},"additionalProperties":false},"list_issue_priorities":{"type":"object","properties":{},"additionalProperties":false},"list_document_categories":{"type":"object","properties":{},"additionalProperties":false}},"minProperties":1,"maxProperties":1,"additionalProperties":false}}]}
    ),
  )
}
