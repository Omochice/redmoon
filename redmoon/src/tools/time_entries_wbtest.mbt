///|
struct FakeTimeEntries {
  lists : Array[@time_entries.ListQuery]
  shows : Array[Int32]
  creates : Array[@time_entries.Create]
  updates : Array[(Int32, @time_entries.Update)]
  deletes : Array[Int32]
  failure : @redmine.RedmineError?
}

///|
fn FakeTimeEntries::new(failure? : @redmine.RedmineError) -> FakeTimeEntries {
  { lists: [], shows: [], creates: [], updates: [], deletes: [], failure, }
}

///|
fn FakeTimeEntries::check(
  self : FakeTimeEntries,
) -> Unit raise @redmine.RedmineError {
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn fake_time_entry(id : Int32) -> @time_entries.Entry {
  {
    id,
    project: { id: 1, name: "demo", },
    issue: None,
    user: { id: 5, name: "Admin", },
    activity: { id: 9, name: "Design", },
    hours: 1.5,
    comments: Some("wrote the port"),
    spent_on: "2026-08-01",
    created_on: "2026-08-01T10:00:00Z",
    updated_on: "2026-08-01T10:00:00Z",
    custom_fields: None,
  }
}

///|
impl TimeEntryPort for FakeTimeEntries with fn list_time_entries(self, query) {
  self.check()
  self.lists.push(query)
  [fake_time_entry(1)]
}

///|
impl TimeEntryPort for FakeTimeEntries with fn show_time_entry(self, id) {
  self.check()
  self.shows.push(id)
  fake_time_entry(id)
}

///|
impl TimeEntryPort for FakeTimeEntries with fn create_time_entry(
  self,
  time_entry,
) {
  self.check()
  self.creates.push(time_entry)
  fake_time_entry(2)
}

///|
impl TimeEntryPort for FakeTimeEntries with fn update_time_entry(
  self,
  id,
  time_entry,
) {
  self.check()
  self.updates.push((id, time_entry))
}

///|
impl TimeEntryPort for FakeTimeEntries with fn delete_time_entry(self, id) {
  self.check()
  self.deletes.push(id)
}

///|
fn time_entry_tools(
  fake : FakeTimeEntries,
  mode~ : Mode = Full,
) -> Array[@mcp.Tool] {
  [time_entries_tool(fake, mode)]
}

///|
async test "list maps every filter onto the query" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "list": {
      "project_id": 1,
      "user_id": 5,
      "spent_on": "2026-08-01",
      "from": "2026-07-01",
      "to": "2026-07-31",
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(fake.lists[0], {
    project_id: Some(1),
    user_id: Some(5),
    spent_on: Some("2026-08-01"),
    from: Some("2026-07-01"),
    to: Some("2026-07-31"),
  })
  assert_true(called.text.contains("\"hours\":1.5"))
}

///|
async test "list with no filters leaves every query field unset" {
  let fake = FakeTimeEntries::new()
  let _ = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "list": {},
  })
  assert_eq(fake.lists[0], {
    project_id: None,
    user_id: None,
    spent_on: None,
    from: None,
    to: None,
  })
}

///|
async test "show passes the id and answers the entry itself" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "show": { "id": 7 },
  })
  assert_eq(fake.shows, [7])
  assert_true(called.text.contains("\"id\":7"))
  assert_false(called.text.contains("\"time_entry\""))
}

///|
async test "create maps every argument onto the attributes" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "create": {
      "hours": 2.25,
      "issue_id": 3,
      "project_id": 1,
      "spent_on": "2026-08-01",
      "activity_id": 9,
      "comments": "wrote the port",
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(fake.creates[0], {
    hours: 2.25,
    issue_id: Some(3),
    project_id: Some(1),
    spent_on: Some("2026-08-01"),
    activity_id: Some(9),
    comments: Some("wrote the port"),
  })
  assert_true(called.text.contains("\"hours\":1.5"))
}

///|
async test "create with only an issue leaves the project and the other attributes unset" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "create": { "hours": 1, "issue_id": 3 },
  })
  assert_eq(called.is_error, false)
  assert_eq(fake.creates[0], {
    hours: 1.0,
    issue_id: Some(3),
    project_id: None,
    spent_on: None,
    activity_id: None,
    comments: None,
  })
}

///|
async test "create with only a project leaves the issue unset" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "create": { "hours": 1, "project_id": 1 },
  })
  assert_eq(called.is_error, false)
  assert_eq(fake.creates[0].issue_id, None)
  assert_eq(fake.creates[0].project_id, Some(1))
}

///|
async test "create with both an issue and a project passes both" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "create": { "hours": 1, "issue_id": 3, "project_id": 1 },
  })
  assert_eq(called.is_error, false)
  assert_eq(fake.creates[0].issue_id, Some(3))
  assert_eq(fake.creates[0].project_id, Some(1))
}

///|
async test "create with neither an issue nor a project is rejected before reaching the port" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "create": { "hours": 1 },
  })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: create: one of `issue_id` and `project_id` is required\"]}",
  )
  assert_true(fake.creates.is_empty())
}

///|
async test "update passes the id and only the changes given" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "update": { "id": 7, "hours": 2, "comments": "revised" },
  })
  assert_eq(called.text, "{\"ok\":true}")
  assert_eq(
    fake.updates[0],
    (
      7,
      {
        hours: Some(2.0),
        issue_id: None,
        project_id: None,
        spent_on: None,
        activity_id: None,
        comments: Some("revised"),
      },
    ),
  )
}

///|
async test "delete passes the id and answers ok" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "delete": { "id": 7 },
  })
  assert_eq(fake.deletes, [7])
  assert_eq(called.text, "{\"ok\":true}")
}

///|
async test "a missing required hours is reported with its action path" {
  let called = call_tool(
    time_entry_tools(FakeTimeEntries::new()),
    "redmine_time_entries",
    { "create": { "project_id": 1 } },
  )
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: create.hours: is required\"]}",
  )
}

///|
async test "negative hours are rejected on create and update, as Redmine refuses them" {
  let fake = FakeTimeEntries::new()
  let tools = time_entry_tools(fake)
  for hours in [-1.0, -0.25] {
    let created = call_tool(tools, "redmine_time_entries", {
      "create": { "hours": hours, "project_id": 1 },
    })
    assert_eq(
      created.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: create.hours: must be at least 0\"]}",
    )
    let updated = call_tool(tools, "redmine_time_entries", {
      "update": { "id": 7, "hours": hours },
    })
    assert_eq(
      updated.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: update.hours: must be at least 0\"]}",
    )
  }
  assert_true(fake.creates.is_empty() && fake.updates.is_empty())
}

///|
async test "zero hours are accepted on create and update" {
  let fake = FakeTimeEntries::new()
  let tools = time_entry_tools(fake)
  let created = call_tool(tools, "redmine_time_entries", {
    "create": { "hours": 0, "project_id": 1 },
  })
  assert_eq(created.is_error, false, msg=created.text)
  assert_eq(fake.creates[0].hours, 0.0)
  let updated = call_tool(tools, "redmine_time_entries", {
    "update": { "id": 7, "hours": 0 },
  })
  assert_eq(updated.is_error, false, msg=updated.text)
  assert_eq(fake.updates[0].1.hours, Some(0.0))
}

///|
async test "comments over 1024 characters are rejected on create and update" {
  let fake = FakeTimeEntries::new()
  let tools = time_entry_tools(fake)
  let long = String::make(1025, 'a')
  let created = call_tool(tools, "redmine_time_entries", {
    "create": { "hours": 1, "project_id": 1, "comments": long },
  })
  assert_eq(
    created.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: create.comments: must be at most 1024 characters\"]}",
  )
  let updated = call_tool(tools, "redmine_time_entries", {
    "update": { "id": 7, "comments": long },
  })
  assert_eq(
    updated.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: update.comments: must be at most 1024 characters\"]}",
  )
  assert_true(fake.creates.is_empty() && fake.updates.is_empty())
}

///|
async test "comments of exactly 1024 characters are accepted on create and update" {
  let fake = FakeTimeEntries::new()
  let tools = time_entry_tools(fake)
  let comments = String::make(1024, 'a')
  let created = call_tool(tools, "redmine_time_entries", {
    "create": { "hours": 1, "project_id": 1, "comments": comments },
  })
  assert_eq(created.is_error, false, msg=created.text)
  assert_eq(fake.creates[0].comments, Some(comments))
  let updated = call_tool(tools, "redmine_time_entries", {
    "update": { "id": 7, "comments": comments },
  })
  assert_eq(updated.is_error, false, msg=updated.text)
  assert_eq(fake.updates[0].1.comments, Some(comments))
}

///|
async test "a malformed date is rejected before reaching the port" {
  let fake = FakeTimeEntries::new()
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "list": { "spent_on": "2026-02-30" },
  })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: list.spent_on: must be a date in the form YYYY-MM-DD\"]}",
  )
  assert_true(fake.lists.is_empty())
}

///|
async test "an id below one is rejected with its bound" {
  let called = call_tool(
    time_entry_tools(FakeTimeEntries::new()),
    "redmine_time_entries",
    { "show": { "id": 0 } },
  )
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: show.id: must be at least 1\"]}",
  )
}

///|
async test "a Redmine failure becomes a failure payload" {
  let fake = FakeTimeEntries::new(
    failure=Response(status=422, errors=["Hours cannot be blank"]),
  )
  let called = call_tool(time_entry_tools(fake), "redmine_time_entries", {
    "create": { "hours": 1, "project_id": 1 },
  })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":422,\"errors\":[\"Hours cannot be blank\"]}",
  )
}

///|
async test "readonly refuses a write as an unknown action" {
  let called = call_tool(
    time_entry_tools(FakeTimeEntries::new(), mode=Readonly),
    "redmine_time_entries",
    { "delete": { "id": 1 } },
  )
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `delete`, one of `list` and `show`\"]}",
  )
}

///|
async test "tools/list advertises the full time entry tool" {
  let advertised = list_tools([time_entries_tool(FakeTimeEntries::new(), Full)])
  inspect(
    advertised.stringify(),
    content=(
      #|{"tools":[{"name":"redmine_time_entries","description":"Create, read, update, and delete Redmine time entries.\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.","inputSchema":{"type":"object","properties":{"list":{"type":"object","properties":{"project_id":{"type":"integer","minimum":1},"user_id":{"type":"integer","minimum":1},"spent_on":{"type":"string","format":"date"},"from":{"type":"string","format":"date"},"to":{"type":"string","format":"date"}},"additionalProperties":false},"show":{"type":"object","properties":{"id":{"type":"integer","minimum":1}},"required":["id"],"additionalProperties":false},"create":{"type":"object","properties":{"hours":{"type":"number","minimum":0},"issue_id":{"type":"integer","minimum":1},"project_id":{"type":"integer","minimum":1},"spent_on":{"type":"string","format":"date"},"activity_id":{"type":"integer","minimum":1},"comments":{"type":"string","maxLength":1024}},"required":["hours"],"additionalProperties":false,"anyOf":[{"required":["issue_id"]},{"required":["project_id"]}]},"update":{"type":"object","properties":{"id":{"type":"integer","minimum":1},"hours":{"type":"number","minimum":0},"issue_id":{"type":"integer","minimum":1},"project_id":{"type":"integer","minimum":1},"spent_on":{"type":"string","format":"date"},"activity_id":{"type":"integer","minimum":1},"comments":{"type":"string","maxLength":1024}},"required":["id"],"additionalProperties":false},"delete":{"type":"object","properties":{"id":{"type":"integer","minimum":1}},"required":["id"],"additionalProperties":false}},"minProperties":1,"maxProperties":1,"additionalProperties":false}}]}
    ),
  )
}

///|
async test "tools/list advertises the readonly time entry tool" {
  let advertised = list_tools([
    time_entries_tool(FakeTimeEntries::new(), Readonly),
  ])
  inspect(
    advertised.stringify(),
    content=(
      #|{"tools":[{"name":"redmine_time_entries","description":"List and show Redmine time entries.\nPass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.","inputSchema":{"type":"object","properties":{"list":{"type":"object","properties":{"project_id":{"type":"integer","minimum":1},"user_id":{"type":"integer","minimum":1},"spent_on":{"type":"string","format":"date"},"from":{"type":"string","format":"date"},"to":{"type":"string","format":"date"}},"additionalProperties":false},"show":{"type":"object","properties":{"id":{"type":"integer","minimum":1}},"required":["id"],"additionalProperties":false}},"minProperties":1,"maxProperties":1,"additionalProperties":false}}]}
    ),
  )
}
