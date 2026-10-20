///|
async test "enumerations come from a real Redmine" {
  let redmine = @livetest.redmine()
  let tools = [@tools.enumerations_tool(redmine)]
  let called = call_tool(tools, "redmine_enumerations", {
    "list_issue_priorities": {},
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"name\":\"Normal\""))
  let offline = @redmine.new(endpoint="http://127.0.0.1:1", api_key="unused")
  let denied = call_tool(
    [@tools.enumerations_tool(offline)],
    "redmine_enumerations",
    { "list_issue_priorities": {} },
  )
  assert_eq(denied.is_error, true)
  assert_true(denied.text.contains("\"status\":0"))
}

///|
async test "saved issue queries come from a real Redmine" {
  let tools = [@tools.enumerations_tool(@livetest.redmine())]
  let called = call_tool(tools, "redmine_enumerations", {
    "list_issue_queries": {},
  })
  assert_eq(called.is_error, false, msg=called.text)
  assert_true(
    called.text.contains("\"name\":\"Demo open issues\""),
    msg=called.text,
  )
}
