///|
struct FakeIssueTemplates {
  calls : Array[String]
  failure : @redmine.RedmineError?
}

///|
fn FakeIssueTemplates::new(
  failure? : @redmine.RedmineError,
) -> FakeIssueTemplates {
  { calls: [], failure, }
}

///|
fn fake_templates() -> @issue_templates.Templates {
  {
    global: [
      {
        id: 1,
        tracker_id: 1,
        title: "Global bug report",
        issue_title: None,
        description: "Steps:\n",
        note: None,
        enabled: true,
        created_on: "2026-01-01T00:00:00Z",
        updated_on: "2026-01-02T00:00:00Z",
      },
    ],
    inherited: [],
    project: [],
  }
}

///|
impl IssueTemplatePort for FakeIssueTemplates with fn list_issue_templates(
  self,
  project,
  tracker_id,
) {
  let label = match project {
    Id(id) => id.to_string()
    Identifier(name) => name
  }
  self.calls.push("list \{label} tracker \{tracker_id}")
  if self.failure is Some(error) {
    raise error
  }
  fake_templates()
}

///|
async test "list reaches the port with the project and answers the templates" {
  let fake = FakeIssueTemplates::new()
  let tools = [issue_templates_tool(fake)]
  let by_identifier = call_tool(tools, "redmine_issue_templates", {
    "list": { "project_id": "demo", "tracker_id": 1 },
  })
  assert_eq(by_identifier.is_error, false)
  assert_eq(
    by_identifier.text,
    "{\"global_issue_templates\":[{\"id\":1,\"tracker_id\":1,\"title\":\"Global bug report\",\"description\":\"Steps:\\n\",\"enabled\":true,\"created_on\":\"2026-01-01T00:00:00Z\",\"updated_on\":\"2026-01-02T00:00:00Z\"}],\"inherit_templates\":[],\"issue_templates\":[]}",
  )
  ignore(
    call_tool(tools, "redmine_issue_templates", {
      "list": { "project_id": 1, "tracker_id": 2 },
    }),
  )
  assert_eq(fake.calls, ["list demo tracker 1", "list 1 tracker 2"])
}

///|
async test "an instance without the plugin answers a 404 failure payload" {
  let tools = [
    issue_templates_tool(
      FakeIssueTemplates::new(failure=Response(status=404, errors=[])),
    ),
  ]
  let called = call_tool(tools, "redmine_issue_templates", {
    "list": { "project_id": "demo", "tracker_id": 1 },
  })
  assert_eq(called.is_error, true)
  assert_eq(called.text, "{\"status\":404,\"errors\":[]}")
}

///|
async test "list requires project_id and tracker_id" {
  let tools = [issue_templates_tool(FakeIssueTemplates::new())]
  let no_project = call_tool(tools, "redmine_issue_templates", {
    "list": { "tracker_id": 1 },
  })
  assert_eq(no_project.is_error, true)
  assert_true(no_project.text.contains("list.project_id"))
  let no_tracker = call_tool(tools, "redmine_issue_templates", {
    "list": { "project_id": "demo" },
  })
  assert_eq(no_tracker.is_error, true)
  assert_true(no_tracker.text.contains("list.tracker_id"))
}

///|
async test "tools/list advertises the issue templates tool" {
  let advertised = list_tools([issue_templates_tool(FakeIssueTemplates::new())]).stringify()
  assert_eq(
    advertised, "{\"tools\":[{\"name\":\"redmine_issue_templates\",\"description\":\"Lists the issue templates a Redmine project offers for new issues of one tracker: the global templates enabled for it, those inherited from its parent projects, and its own.\\n`tracker_id` is the tracker's id, as an issue from `redmine_issues` carries it under `tracker`.\\nNeeds the redmine_issue_templates plugin; an instance without it answers 404.\\nPass the arguments under the single key `list`: `{\\\"list\\\": {\\\"project_id\\\": \\\"demo\\\", \\\"tracker_id\\\": 1}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"pattern\":\"^\\\\S+$\"}],\"description\":\"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).\"},\"tracker_id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"project_id\",\"tracker_id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "live: issue templates come through the tool" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = @redmine.new(endpoint~, api_key~)
  let tools = [issue_templates_tool(redmine)]
  let called = call_tool(tools, "redmine_issue_templates", {
    "list": { "project_id": "demo", "tracker_id": 1 },
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"title\":\"Bug report\""))
  assert_true(called.text.contains("\"title\":\"Global bug report\""))
  let missing = call_tool(tools, "redmine_issue_templates", {
    "list": { "project_id": "no-such-project", "tracker_id": 1 },
  })
  assert_eq(missing.is_error, true)
  assert_true(missing.text.contains("\"status\":404"))
}
