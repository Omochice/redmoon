///|
struct FakeEnumerations {
  failure : @redmine.RedmineError?
}

///|
fn fake_enumeration(id : Int32, name : String) -> @redmine.Enumeration {
  { id, name, is_default: id == 9, active: true, }
}

///|
fn FakeEnumerations::check(
  self : FakeEnumerations,
) -> Unit raise @redmine.RedmineError {
  if self.failure is Some(error) {
    raise error
  }
}

///|
impl EnumerationPort for FakeEnumerations with fn list_time_entry_activities(
  self,
) {
  self.check()
  [fake_enumeration(9, "Design"), fake_enumeration(10, "Development")]
}

///|
impl EnumerationPort for FakeEnumerations with fn list_issue_priorities(self) {
  self.check()
  [fake_enumeration(1, "Low"), fake_enumeration(2, "Normal")]
}

///|
impl EnumerationPort for FakeEnumerations with fn list_document_categories(self) {
  self.check()
  [fake_enumeration(3, "User documentation")]
}

///|
fn fake_tools(failure? : @redmine.RedmineError) -> Array[@mcp.Tool] {
  [enumerations_tool(FakeEnumerations::{ failure, })]
}

///|
async test "each listing reaches its own port method" {
  let tools = fake_tools()
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
  let tools = fake_tools(failure=Response(status=403, errors=["Forbidden"]))
  let called = call_tool(tools, "redmine_enumerations", {
    "list_issue_priorities": {},
  })
  assert_eq(called.is_error, true)
  assert_eq(called.text, "{\"status\":403,\"errors\":[\"Forbidden\"]}")
}

///|
async test "an unknown action is reported with the invalid arguments wording" {
  let called = call_tool(fake_tools(), "redmine_enumerations", {
    "list_nothing": {},
  })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `list_nothing`, one of: list_time_entry_activities, list_issue_priorities, list_document_categories\"]}",
  )
}

///|
async test "a stray argument is reported with its action path" {
  let called = call_tool(fake_tools(), "redmine_enumerations", {
    "list_issue_priorities": { "x": 1 },
  })
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: list_issue_priorities.x: unknown field\"]}",
  )
}

///|
async test "tools/list advertises the same enumerations tool in both modes" {
  let advertised = []
  for mode in [Mode::Full, Readonly] {
    advertised.push(
      list_tools(
        build_tools(
          [always(enumerations_tool(FakeEnumerations::{ failure: None, }))],
          mode,
        ),
      ).stringify(),
    )
  }
  assert_eq(advertised[0], advertised[1])
  assert_eq(
    advertised[0],
    "{\"tools\":[{\"name\":\"redmine_enumerations\",\"description\":\"Lists the Redmine enumerations that supply ids other tools require: time entry activities for `activity_id`, issue priorities for `priority_id`, and document categories.\\nName the listing as the only key, with an empty object as its value: `{\\\"list_issue_priorities\\\": {}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list_time_entry_activities\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false},\"list_issue_priorities\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false},\"list_document_categories\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "live: enumerations come from a real Redmine" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = @redmine.Redmine::new(endpoint~, api_key~)
  let tools = [enumerations_tool(redmine)]
  let called = call_tool(tools, "redmine_enumerations", {
    "list_issue_priorities": {},
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"name\":\"Normal\""))
  let offline = @redmine.Redmine::new(endpoint="http://127.0.0.1:1", api_key~)
  let denied = call_tool([enumerations_tool(offline)], "redmine_enumerations", {
    "list_issue_priorities": {},
  })
  assert_eq(denied.is_error, true)
  assert_true(denied.text.contains("\"status\":0"))
}
