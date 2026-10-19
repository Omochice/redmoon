///|
struct FakeIssues {
  failure : @redmine.RedmineError?
  mut listed : (@issues.ListQuery, Int32?)?
  mut shown : (Int32, Array[@issues.Include])?
  mut created : @issues.Create?
  mut updated : (Int32, @issues.Update)?
  mut deleted : Int32?
  mut journal : (Int32, String?, Bool?)?
}

///|
fn FakeIssues::new(failure? : @redmine.RedmineError) -> FakeIssues {
  {
    failure,
    listed: None,
    shown: None,
    created: None,
    updated: None,
    deleted: None,
    journal: None,
  }
}

///|
fn fake_issue(id : Int32, subject : String) -> @issues.Issue {
  {
    id,
    project: { id: 1, name: "Demo", },
    tracker: { id: 1, name: "Bug", },
    status: { id: 1, name: "New", is_closed: Some(false), },
    priority: { id: 2, name: "Normal", },
    author: { id: 1, name: "Admin", },
    assigned_to: None,
    category: None,
    fixed_version: None,
    parent: None,
    subject,
    description: None,
    start_date: None,
    due_date: None,
    done_ratio: 0,
    is_private: false,
    estimated_hours: None,
    total_estimated_hours: None,
    spent_hours: None,
    total_spent_hours: None,
    created_on: "2026-01-01T00:00:00Z",
    updated_on: "2026-01-01T00:00:00Z",
    closed_on: None,
    custom_fields: None,
    journals: None,
    attachments: None,
    relations: None,
    children: None,
    changesets: None,
    watchers: None,
    allowed_statuses: None,
  }
}

///|
fn FakeIssues::check(self : FakeIssues) -> Unit raise @redmine.RedmineError {
  if self.failure is Some(error) {
    raise error
  }
}

///|
impl IssuePort for FakeIssues with fn list_issues(self, query, limit) {
  self.check()
  self.listed = Some((query, limit))
  [fake_issue(1, "first"), fake_issue(2, "second")]
}

///|
impl IssuePort for FakeIssues with fn show_issue(self, id, includes) {
  self.check()
  self.shown = Some((id, includes))
  fake_issue(id, "shown")
}

///|
impl IssuePort for FakeIssues with fn create_issue(self, issue) {
  self.check()
  self.created = Some(issue)
  fake_issue(7, issue.subject)
}

///|
impl IssuePort for FakeIssues with fn update_issue(self, id, update) {
  self.check()
  self.updated = Some((id, update))
}

///|
impl IssuePort for FakeIssues with fn delete_issue(self, id) {
  self.check()
  self.deleted = Some(id)
}

///|
impl IssuePort for FakeIssues with fn update_journal(
  self,
  id,
  notes,
  private_notes,
) {
  self.check()
  self.journal = Some((id, notes, private_notes))
}

///|
async fn call_issues(
  fake : FakeIssues,
  arguments : Json,
  mode~ : Mode = Full,
) -> Called {
  call_tool([issues_tool(fake, mode)], "redmine_issues", arguments)
}

///|
async fn listed_with(arguments : Json) -> @issues.ListQuery {
  let fake = FakeIssues::new()
  let called = call_issues(fake, { "list": arguments })
  assert_eq(called.is_error, false, msg=called.text)
  fake.listed.unwrap().0
}

///|
async fn created_with(arguments : Json) -> @issues.Create {
  let fake = FakeIssues::new()
  let called = call_issues(fake, { "create": arguments })
  assert_eq(called.is_error, false, msg=called.text)
  fake.created.unwrap()
}

///|
async fn updated_with(arguments : Json) -> @issues.Update {
  let fake = FakeIssues::new()
  let called = call_issues(fake, { "update": arguments })
  assert_eq(called.is_error, false, msg=called.text)
  fake.updated.unwrap().1
}

///|
async fn rejected(action : String, arguments : Json) -> String {
  let fake = FakeIssues::new()
  let called = call_issues(fake, single(action, arguments))
  assert_eq(called.is_error, true, msg="accepted \{arguments.stringify()}")
  assert_true(
    fake.listed is None &&
    fake.created is None &&
    fake.updated is None &&
    fake.journal is None,
  )
  called.text
}

///|
fn single(key : String, value : Json) -> Json {
  let fields : Map[String, Json] = Map([])
  fields[key] = value
  Json::object(fields)
}

///|
fn new_update(field : String) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["id"] = 1
  fields[field] = Json::null()
  Json::object(fields)
}

///|
let new_issue : Json = {
  "project_id": 1,
  "tracker_id": 1,
  "status_id": 1,
  "priority_id": 2,
  "subject": "planned",
}

///|
fn with_field(base : Json, name : String, value : Json) -> Json {
  guard base is Object(fields) else { abort("not an object") }
  let merged : Map[String, Json] = Map([])
  for key, existing in fields {
    merged[key] = existing
  }
  merged[name] = value
  Json::object(merged)
}

///|
fn at(json : Json, path : Array[String]) -> Json raise {
  let mut current = json
  for key in path {
    guard current is Object(fields) && fields.get(key) is Some(next) else {
      fail("no `\{key}` in \{current.stringify()}")
    }
    current = next
  }
  current
}

///|
async fn advertised_issues(mode : Mode) -> Json {
  let listing = list_tools([issues_tool(FakeIssues::new(), mode)])
  at(listing, ["tools"])
}

///|
async fn advertised_action(action : String) -> Json {
  let tools = advertised_issues(Full)
  guard tools is [tool] else { fail("expected one tool") }
  at(tool, ["inputSchema", "properties", action])
}

///|
async test "list sends its conditions and limit to the port" {
  let fake = FakeIssues::new()
  let called = call_issues(fake, {
    "list": {
      "include": ["attachments", "relations"],
      "project_id": 1,
      "tracker_id": 2,
      "status_id": "open",
      "fixed_version_id": 42,
      "assigned_to_id": "me",
      "limit": 5,
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(
    called.text.contains("\"subject\":\"first\"") &&
    called.text.contains("\"subject\":\"second\""),
    true,
  )
  let (query, limit) = fake.listed.unwrap()
  assert_eq(limit, Some(5))
  assert_eq(query.includes, [Attachments, Relations])
  assert_eq(query.project_id, Some(1))
  assert_eq(query.tracker_id, Some(2))
  assert_eq(query.status_id, Some(Open))
  assert_eq(query.fixed_version_id, Some(42))
  assert_eq(query.assigned_to_id, Some(Me))
}

///|
async test "list without arguments filters nothing" {
  let query = listed_with({})
  assert_eq(query.includes, [])
  assert_eq(query.project_id, None)
  assert_eq(query.status_id, None)
  assert_eq(query.created_on, None)
}

///|
async test "list reads the status and assignee unions" {
  assert_eq(listed_with({ "status_id": 3 }).status_id, Some(Id(3)))
  assert_eq(listed_with({ "status_id": "closed" }).status_id, Some(Closed))
  assert_eq(listed_with({ "status_id": "*" }).status_id, Some(All))
  assert_eq(listed_with({ "assigned_to_id": 9 }).assigned_to_id, Some(User(9)))
  ignore(rejected("list", { "status_id": "pending" }))
  ignore(rejected("list", { "assigned_to_id": "you" }))
  ignore(rejected("list", { "project_id": 0 }))
}

///|
async test "list rejects an association only show can fetch" {
  ignore(rejected("list", { "include": ["journals"] }))
}

///|
async test "show sends the id and the associations it was asked to include" {
  let fake = FakeIssues::new()
  let called = call_issues(fake, {
    "show": {
      "id": 4,
      "include": [
        "journals", "attachments", "relations", "children", "changesets", "watchers",
        "allowedStatuses",
      ],
    },
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"subject\":\"shown\""))
  assert_eq(
    fake.shown.unwrap(),
    (
      4,
      [
        Journals,
        Attachments,
        Relations,
        Children,
        Changesets,
        Watchers,
        AllowedStatuses,
      ],
    ),
  )
}

///|
async test "show without include asks for the bare issue" {
  let fake = FakeIssues::new()
  ignore(call_issues(fake, { "show": { "id": 4 } }))
  assert_eq(fake.shown.unwrap(), (4, []))
}

///|
async test "show rejects an association Redmine does not have and a missing id" {
  ignore(rejected("show", { "id": 1, "include": ["comments"] }))
  ignore(rejected("show", { "include": ["journals"] }))
  ignore(rejected("show", { "id": 0 }))
}

///|
async test "list keeps every date filter field" {
  let query = listed_with({
    "start_date": "2026-07-01",
    "due_date": { "days_from_now": 3 },
    "created_on": "thisWeek",
    "updated_on": { "from": { "days_ago": 7 } },
    "closed_on": { "to": "2026-07-01" },
  })
  assert_eq(query.start_date, Some(Past(On("2026-07-01"))))
  assert_eq(query.due_date, Some(DaysFromNow(3)))
  assert_eq(query.created_on, Some(Period(ThisWeek)))
  assert_eq(query.updated_on, Some(SinceDaysAgo(7)))
  assert_eq(query.closed_on, Some(Until("2026-07-01")))
}

///|
async test "every named period reaches the filter" {
  let periods : Array[(String, @issues.DatePeriod)] = [
    ("today", Today),
    ("yesterday", Yesterday),
    ("thisWeek", ThisWeek),
    ("lastWeek", LastWeek),
    ("lastTwoWeeks", LastTwoWeeks),
    ("thisMonth", ThisMonth),
    ("lastMonth", LastMonth),
    ("thisYear", ThisYear),
    ("any", Any),
    ("none", Blank),
  ]
  for entry in periods {
    let query = listed_with({ "created_on": entry.0, "due_date": entry.0 })
    assert_eq(query.created_on, Some(Period(entry.1)))
    assert_eq(query.due_date, Some(Past(Period(entry.1))))
  }
}

///|
async test "a two-ended range keeps both bounds" {
  let query = listed_with({
    "created_on": { "from": "2026-01-01", "to": "2026-02-01" },
  })
  assert_eq(query.created_on, Some(Between(from="2026-01-01", to="2026-02-01")))
}

///|
async test "the past forms map to their own filters" {
  let cases : Array[(Json, @issues.PastDateFilter)] = [
    ("2026-07-01", On("2026-07-01")),
    ({ "days_ago": 0 }, DaysAgo(0)),
    ({ "from": "2026-07-01" }, Since("2026-07-01")),
    ({ "to": "2026-07-01" }, Until("2026-07-01")),
    ({ "from": { "days_ago": 7 } }, SinceDaysAgo(7)),
    ({ "from": { "days_ago": 7 }, "to": "today" }, LastDays(7)),
    ({ "to": { "days_ago": 7 } }, UntilDaysAgo(7)),
  ]
  for entry in cases {
    let query = listed_with({ "updated_on": entry.0 })
    assert_eq(query.updated_on, Some(entry.1))
  }
}

///|
async test "the future forms map to their own filters" {
  let cases : Array[(Json, @issues.DateFilter)] = [
    ("tomorrow", Tomorrow),
    ("nextWeek", NextWeek),
    ("nextMonth", NextMonth),
    ({ "days_from_now": 3 }, DaysFromNow(3)),
    ({ "from": { "days_from_now": 3 } }, SinceDaysFromNow(3)),
    ({ "to": { "days_from_now": 3 } }, UntilDaysFromNow(3)),
    ({ "from": "today", "to": { "days_from_now": 3 } }, NextDays(3)),
  ]
  for entry in cases {
    let query = listed_with({ "due_date": entry.0 })
    assert_eq(query.due_date, Some(entry.1))
  }
}

///|
async test "a date filter rejects anything but an ISO date" {
  for value in ["2026/07/01", "2026-02-30", "last week", "Today"] {
    ignore(rejected("list", { "created_on": value }))
  }
}

///|
async test "the :date_past fields reject future-looking filters" {
  let future : Array[Json] = [
    "tomorrow",
    "nextWeek",
    "nextMonth",
    { "days_from_now": 3 },
    { "from": { "days_from_now": 3 } },
    { "to": { "days_from_now": 3 } },
    { "from": "today", "to": { "days_from_now": 3 } },
  ]
  for field in ["created_on", "updated_on", "closed_on"] {
    for value in future {
      ignore(rejected("list", single(field, value)))
    }
  }
  assert_eq(listed_with({ "due_date": "tomorrow" }).due_date, Some(Tomorrow))
}

///|
async test "a range is a strict object that never drops a bound" {
  let malformed : Array[Json] = [
    {},
    { "from": "2026-01-01", "to": "2026-02-01", "extra": 1 },
    { "from": { "days_ago": 7 }, "to": "2026-02-01" },
    { "from": { "days_ago": 7 }, "to": { "days_ago": 1 } },
    { "from": { "days_ago": 7, "days_from_now": 1 } },
    { "days_ago": 7, "extra": 1 },
    { "days_ago": -1 },
    { "days_ago": 1.5 },
    { "daysAgo": 1 },
  ]
  for value in malformed {
    ignore(rejected("list", { "created_on": value }))
  }
  ignore(rejected("list", { "due_date": { "from": "tomorrow" } }))
}

///|
async test "a camelCase argument is reported as an unknown field" {
  assert_eq(
    rejected("list", { "projectId": 1 }),
    "{\"status\":0,\"errors\":[\"invalid arguments: list.projectId: unknown field\"]}",
  )
}

///|
async test "list reports a date filter that matches no form" {
  assert_eq(
    rejected("list", { "created_on": "2026/07/01" }),
    "{\"status\":0,\"errors\":[\"invalid arguments: list.created_on: no alternative matched: must be a date in the form YYYY-MM-DD; must be one of today, yesterday, thisWeek, lastWeek, lastTwoWeeks, thisMonth, lastMonth, thisYear, any, none; expected an object\"]}",
  )
}

///|
async test "create sends every field and answers with the created issue" {
  let fake = FakeIssues::new()
  let called = call_issues(fake, {
    "create": {
      "project_id": 1,
      "tracker_id": 2,
      "status_id": 3,
      "priority_id": 4,
      "subject": "planned",
      "description": "details",
      "fixed_version_id": 42,
      "assigned_to_id": 5,
      "parent_issue_id": 6,
      "start_date": "2026-07-01",
      "due_date": "2026-07-31",
      "is_private": true,
      "estimated_hours": 1.5,
    },
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"id\":7"))
  assert_true(called.text.contains("\"subject\":\"planned\""))
  let issue = fake.created.unwrap()
  assert_eq(issue.project_id, 1)
  assert_eq(issue.tracker_id, 2)
  assert_eq(issue.status_id, 3)
  assert_eq(issue.priority_id, 4)
  assert_eq(issue.subject, "planned")
  assert_eq(issue.description, Some("details"))
  assert_eq(issue.fixed_version_id, Some(42))
  assert_eq(issue.assigned_to_id, Some(5))
  assert_eq(issue.parent_issue_id, Some(6))
  assert_eq(issue.start_date, Some("2026-07-01"))
  assert_eq(issue.due_date, Some("2026-07-31"))
  assert_eq(issue.is_private, Some(true))
  assert_eq(issue.estimated_hours, Some(1.5))
}

///|
async test "create sends only the required fields when nothing else is given" {
  let issue = created_with(new_issue)
  assert_eq(issue.description, None)
  assert_eq(issue.fixed_version_id, None)
  assert_eq(issue.start_date, None)
  assert_eq(issue.is_private, None)
}

///|
async test "create sends a single-value custom field to the port" {
  let issue = created_with(
    with_field(new_issue, "custom_fields", [{ "id": 3, "value": "high" }]),
  )
  assert_eq(issue.custom_fields, Some([{ id: 3, value: Single("high"), }]))
}

///|
async test "create sends a multi-value custom field as an array of strings" {
  let issue = created_with(
    with_field(new_issue, "custom_fields", [
      { "id": 4, "value": ["linux", "macos"] },
    ]),
  )
  assert_eq(
    issue.custom_fields,
    Some([{ id: 4, value: Multiple(["linux", "macos"]), }]),
  )
}

///|
async fn rejected_custom_field(entry : Json) -> String {
  rejected("create", with_field(new_issue, "custom_fields", [entry]))
}

///|
async test "a custom field value must be a string or an array of strings, since Redmine reads every value as text" {
  let not_text = "{\"status\":0,\"errors\":[\"invalid arguments: create.custom_fields.0.value: no alternative matched: expected a string; expected an array\"]}"
  for value in [Json::number(3), Json::boolean(true), Json::null()] {
    assert_eq(rejected_custom_field({ "id": 3, "value": value }), not_text)
  }
  assert_eq(
    rejected_custom_field({ "id": 3, "value": [1, 2] }),
    "{\"status\":0,\"errors\":[\"invalid arguments: create.custom_fields.0.value.0: expected a string\"]}",
  )
}

///|
async test "a custom field entry names its field by id and nothing else" {
  for
    case in [
      (({ "value": "high" } : Json), "create.custom_fields.0.id: is required"),
      ({ "id": 3 }, "create.custom_fields.0.value: is required"),
      (
        { "id": 0, "value": "high" },
        "create.custom_fields.0.id: must be at least 1",
      ),
      (
        { "id": 3, "name": "Severity", "value": "high" },
        "create.custom_fields.0.name: unknown field",
      ),
    ] {
    let (entry, error) = case
    assert_eq(
      rejected_custom_field(entry),
      "{\"status\":0,\"errors\":[\"invalid arguments: \{error}\"]}",
    )
  }
}

///|
async test "create requires its identifying fields" {
  for
    name in ["project_id", "tracker_id", "status_id", "priority_id", "subject"] {
    guard new_issue is Object(fields) else { abort("not an object") }
    let without : Map[String, Json] = Map([])
    for key, value in fields {
      if key != name {
        without[key] = value
      }
    }
    assert_eq(
      rejected("create", Json::object(without)),
      "{\"status\":0,\"errors\":[\"invalid arguments: create.\{name}: is required\"]}",
    )
  }
}

///|
async test "create rejects a null fixed_version_id, since a new issue has no version to leave" {
  ignore(
    rejected("create", with_field(new_issue, "fixed_version_id", Json::null())),
  )
}

///|
async test "create rejects a null date, since a new issue has no date to clear" {
  ignore(rejected("create", with_field(new_issue, "start_date", Json::null())))
  ignore(rejected("create", with_field(new_issue, "due_date", Json::null())))
}

///|
async test "create rejects the filter forms of the date fields, which name no day to write" {
  ignore(
    rejected(
      "create",
      with_field(new_issue, "start_date", { "days_from_now": 3 }),
    ),
  )
  ignore(rejected("create", with_field(new_issue, "due_date", "nextWeek")))
}

///|
async test "update sends the changes under the issue id" {
  let fake = FakeIssues::new()
  let called = call_issues(fake, {
    "update": {
      "id": 9,
      "subject": "renamed",
      "description": "text",
      "status_id": 5,
      "priority_id": 3,
      "tracker_id": 2,
      "done_ratio": 50,
      "is_private": false,
      "estimated_hours": 2.5,
      "notes": "closing",
      "private_notes": true,
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"ok\":true}")
  let (id, update) = fake.updated.unwrap()
  assert_eq(id, 9)
  assert_eq(update.subject, Some("renamed"))
  assert_eq(update.description, Some("text"))
  assert_eq(update.status_id, Some(5))
  assert_eq(update.priority_id, Some(3))
  assert_eq(update.tracker_id, Some(2))
  assert_eq(update.done_ratio, Some(50))
  assert_eq(update.is_private, Some(false))
  assert_eq(update.estimated_hours, Some(2.5))
  assert_eq(update.notes, Some("closing"))
  assert_eq(update.private_notes, Some(true))
  assert_eq(update.assigned_to_id, None)
  assert_eq(update.start_date, None)
}

///|
async test "update sends custom fields as given, empty values included" {
  let update = updated_with({
    "id": 1,
    "custom_fields": [
      { "id": 3, "value": "low" },
      { "id": 4, "value": ["linux"] },
      { "id": 5, "value": "" },
      { "id": 6, "value": [] },
    ],
  })
  assert_eq(
    update.custom_fields,
    Some([
      { id: 3, value: Single("low"), },
      { id: 4, value: Multiple(["linux"]), },
      { id: 5, value: Single(""), },
      { id: 6, value: Multiple([]), },
    ]),
  )
}

///|
async test "update empties a custom field given null, sending the empty string Redmine reads as empty for either kind of field" {
  let update = updated_with({
    "id": 1,
    "custom_fields": [{ "id": 3, "value": null }],
  })
  assert_eq(update.custom_fields, Some([{ id: 3, value: Single(""), }]))
}

///|
async test "update sets a value or clears it with null" {
  let set = updated_with({
    "id": 1,
    "assigned_to_id": 7,
    "category_id": 8,
    "parent_issue_id": 9,
    "fixed_version_id": 42,
    "start_date": "2026-07-01",
    "due_date": "2026-07-31",
  })
  assert_eq(set.assigned_to_id, Some(Set(7)))
  assert_eq(set.category_id, Some(Set(8)))
  assert_eq(set.parent_issue_id, Some(Set(9)))
  assert_eq(set.fixed_version_id, Some(Set(42)))
  assert_eq(set.start_date, Some(Set("2026-07-01")))
  assert_eq(set.due_date, Some(Set("2026-07-31")))
  let cleared = updated_with({
    "id": 1,
    "assigned_to_id": null,
    "category_id": null,
    "parent_issue_id": null,
    "fixed_version_id": null,
    "start_date": null,
    "due_date": null,
  })
  assert_eq(cleared.assigned_to_id, Some(Clear))
  assert_eq(cleared.category_id, Some(Clear))
  assert_eq(cleared.parent_issue_id, Some(Clear))
  assert_eq(cleared.fixed_version_id, Some(Clear))
  assert_eq(cleared.start_date, Some(Clear))
  assert_eq(cleared.due_date, Some(Clear))
}

///|
async test "update rejects null for the fields that cannot be emptied" {
  for
    name in [
      "status_id", "priority_id", "tracker_id", "subject", "done_ratio", "custom_fields",
    ] {
    ignore(rejected("update", new_update(name)))
  }
}

///|
async test "update rejects the filter forms of the date fields, which name no day to write" {
  ignore(rejected("update", { "id": 1, "start_date": { "days_from_now": 3 } }))
  ignore(rejected("update", { "id": 1, "due_date": "nextWeek" }))
}

///|
async test "delete and delete_note answer ok" {
  let fake = FakeIssues::new()
  let deleted = call_issues(fake, { "delete": { "id": 3 } })
  assert_eq(deleted.text, "{\"ok\":true}")
  assert_eq(fake.deleted, Some(3))
  let erased = call_issues(fake, { "delete_note": { "journal_id": 12 } })
  assert_eq(erased.text, "{\"ok\":true}")
  assert_eq(fake.journal.unwrap(), (12, Some(""), None))
}

///|
async test "update_note replaces the text, optionally with its privacy" {
  let fake = FakeIssues::new()
  ignore(
    call_issues(fake, { "update_note": { "journal_id": 1, "notes": "edited" } }),
  )
  assert_eq(fake.journal.unwrap(), (1, Some("edited"), None))
  ignore(
    call_issues(fake, {
      "update_note": {
        "journal_id": 2,
        "notes": "hidden",
        "private_notes": true,
      },
    }),
  )
  assert_eq(fake.journal.unwrap(), (2, Some("hidden"), Some(true)))
}

///|
async test "update_note accepts private_notes alone so a comment can be hidden without retyping it" {
  let fake = FakeIssues::new()
  let called = call_issues(fake, {
    "update_note": { "journal_id": 1, "private_notes": true },
  })
  assert_eq(called.is_error, false)
  assert_eq(fake.journal.unwrap(), (1, None, Some(true)))
}

///|
async test "update_note rejects empty notes, which would erase the comment" {
  ignore(rejected("update_note", { "journal_id": 1, "notes": "" }))
}

///|
async test "update_note rejects a call that changes neither notes nor private_notes" {
  ignore(rejected("update_note", { "journal_id": 1 }))
}

///|
async test "update_note does not lose a notes that is not text" {
  ignore(
    rejected("update_note", {
      "journal_id": 1,
      "notes": 5,
      "private_notes": true,
    }),
  )
}

///|
async test "readonly omits every write action" {
  let calls : Array[Json] = [
    { "create": new_issue },
    { "update": { "id": 1, "subject": "x" } },
    { "delete": { "id": 1 } },
    { "update_note": { "journal_id": 1, "notes": "edited" } },
    { "delete_note": { "journal_id": 1 } },
  ]
  for arguments in calls {
    let fake = FakeIssues::new()
    let called = call_issues(fake, arguments, mode=Readonly)
    assert_eq(called.is_error, true)
    assert_true(called.text.contains("unknown action"))
    let full = call_issues(fake, arguments)
    assert_eq(full.is_error, false, msg=full.text)
  }
  let read = call_issues(FakeIssues::new(), { "list": {} }, mode=Readonly)
  assert_eq(read.is_error, false)
}

///|
async test "a Redmine failure becomes a failure payload" {
  let fake = FakeIssues::new(failure=Response(status=404, errors=["Not Found"]))
  let calls : Array[Json] = [
    { "show": { "id": 1 } },
    { "list": {} },
    { "create": new_issue },
    { "update": { "id": 1, "subject": "x" } },
    { "delete": { "id": 1 } },
    { "update_note": { "journal_id": 1, "notes": "x" } },
    { "delete_note": { "journal_id": 1 } },
  ]
  for arguments in calls {
    let called = call_issues(fake, arguments)
    assert_eq(called.is_error, true)
    assert_eq(called.text, "{\"status\":404,\"errors\":[\"Not Found\"]}")
  }
}

///|
async test "the date filters survive the JSON Schema the server advertises" {
  let list = advertised_action("list")
  assert_true(at(list, ["properties", "created_on", "anyOf"]) is Array(_))
}

///|
async test "every date filter form advertises what it means" {
  let list = advertised_action("list")
  let mut described = 0
  for
    field in ["start_date", "due_date", "created_on", "updated_on", "closed_on"] {
    guard at(list, ["properties", field, "anyOf"]) is Array(forms) else {
      fail("\{field} is not a union")
    }
    for form in forms {
      if at(form, ["type"]) is String("object") {
        described += 1
        assert_true(
          at(form, ["description"]) is String(_),
          msg="\{field} advertises a form with no description: \{form.stringify()}",
        )
      }
    }
  }
  let past_forms = 5
  let future_forms = 4
  assert_eq(described, 3 * past_forms + 2 * (past_forms + future_forms))
}

///|
async test "the update dates advertise that they are written, not filtered, and that null clears them" {
  let update = advertised_action("update")
  for field in ["start_date", "due_date"] {
    guard at(update, ["properties", field, "description"]) is String(text) else {
      fail("no description")
    }
    assert_true(text.contains("YYYY-MM-DD"))
    assert_true(text.contains("`null` clears"))
  }
}

///|
async test "the create dates advertise that they are written, not filtered" {
  let create = advertised_action("create")
  for field in ["start_date", "due_date"] {
    guard at(create, ["properties", field, "description"]) is String(text) else {
      fail("no description")
    }
    assert_true(text.contains("YYYY-MM-DD"))
    assert_true(text.contains("on `list`"))
    assert_false(text.contains("clears"))
  }
}

///|
async test "custom_fields advertises where the ids are listed, that values are text, and that only update empties one, with null" {
  for action in ["create", "update"] {
    guard at(advertised_action(action), [
        "properties", "custom_fields", "description",
      ])
      is String(text) else {
      fail("no description on \{action}")
    }
    assert_true(text.contains("`show`"), msg=text)
    assert_true(text.contains("`\"3\"`"), msg=text)
    assert_eq(text.contains("`null` empties"), action == "update", msg=text)
    assert_false(text.contains("`\"\"`"), msg=text)
  }
}

///|
async test "status_id advertises that a forbidden transition is ignored and where the allowed ones are listed" {
  let update = advertised_action("update")
  guard at(update, ["properties", "status_id", "description"]) is String(text) else {
    fail("no description")
  }
  assert_true(text.contains("ignore"))
  assert_true(text.contains("allowedStatuses"))
}

///|
async test "update_note is advertised as one action holding both of its branches" {
  let note = advertised_action("update_note")
  assert_true(at(note, ["anyOf"]) is [_, _])
}

///|
async test "the tool description names the comment actions only in full mode" {
  for mode in [Mode::Full, Readonly] {
    let tools = advertised_issues(mode)
    guard tools is [tool] else { fail("expected one tool") }
    guard at(tool, ["description"]) is String(text) else {
      fail("no description")
    }
    assert_eq(text.contains("`update_note` edits"), mode is Full)
    assert_true(
      text.contains("`list` accepts only `attachments` and `relations`."),
    )
  }
}

///|
async test "live: issues are created, shown, updated, commented and deleted through the tool" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = @redmine.new(endpoint~, api_key~)
  let tools = [issues_tool(redmine, Full)]
  let subject = "redmoon-issues-tool-\{@env.now()}"
  let created = call_tool(tools, "redmine_issues", {
    "create": {
      "project_id": 1,
      "tracker_id": 1,
      "status_id": 1,
      "priority_id": 2,
      "subject": subject,
      "start_date": "2026-01-01",
    },
  })
  assert_eq(created.is_error, false, msg=created.text)
  guard @json.parse(created.text) is { "id": Number(id, ..), .. } else {
    fail("no id in \{created.text}")
  }
  let id = id.to_int()
  let outcome : Error? = try {
    exercise_live_issue(tools, id, subject)
    None
  } catch {
    error => Some(error)
  }
  let deleted = call_tool(tools, "redmine_issues", { "delete": { "id": id } })
  assert_eq(deleted.text, "{\"ok\":true}")
  if outcome is Some(error) {
    raise error
  }
  let gone = call_tool(tools, "redmine_issues", { "show": { "id": id } })
  assert_eq(gone.is_error, true)
  assert_true(gone.text.contains("\"status\":404"))
}

///|
async fn exercise_live_issue(
  tools : Array[@mcp.Tool],
  id : Int32,
  subject : String,
) -> Unit {
  let listed = call_tool(tools, "redmine_issues", {
    "list": {
      "project_id": 1,
      "status_id": "*",
      "created_on": "today",
      "limit": 100,
    },
  })
  assert_eq(listed.is_error, false, msg=listed.text)
  assert_true(listed.text.contains(subject))
  let updated = call_tool(tools, "redmine_issues", {
    "update": {
      "id": id,
      "subject": subject + "-edited",
      "start_date": null,
      "notes": "a comment",
    },
  })
  assert_eq(updated.text, "{\"ok\":true}")
  let shown = call_tool(tools, "redmine_issues", {
    "show": { "id": id, "include": ["journals"] },
  })
  assert_true(shown.text.contains(subject + "-edited"))
  assert_false(shown.text.contains("\"start_date\":\"2026"))
  guard @json.parse(shown.text)
    is { "journals": [{ "id": Number(journal, ..), .. }, ..], .. } else {
    fail("no journal in \{shown.text}")
  }
  let edited = call_tool(tools, "redmine_issues", {
    "update_note": { "journal_id": journal.to_int(), "notes": "edited comment" },
  })
  assert_eq(edited.text, "{\"ok\":true}")
  let again = call_tool(tools, "redmine_issues", {
    "show": { "id": id, "include": ["journals"] },
  })
  assert_true(again.text.contains("edited comment"))
  let hidden = call_tool(tools, "redmine_issues", {
    "update_note": { "journal_id": journal.to_int(), "private_notes": true },
  })
  assert_eq(hidden.text, "{\"ok\":true}")
  let erased = call_tool(tools, "redmine_issues", {
    "delete_note": { "journal_id": journal.to_int() },
  })
  assert_eq(erased.text, "{\"ok\":true}")
}

///|
/// The id of the seeded custom field `name`, read from the administrator-only
/// listing because the seed order decides it.
async fn seeded_custom_field(
  redmine : @redmine.Redmine,
  name : String,
) -> Int32 {
  guard @redmine.send(redmine, Get, ["custom_fields.json"])
    is { "custom_fields": Array(fields), .. } else {
    fail("no custom_fields listing")
  }
  for field in fields {
    if field is { "id": Number(id, ..), "name": String(found), .. } &&
      found == name {
      return id.to_int()
    }
  }
  fail("custom field \{name} is not seeded; run `task redmine:seed`")
}

///|
fn custom_field_value(issue : Json, id : Int32) -> Json raise {
  guard issue is { "custom_fields": Array(fields), .. } else {
    fail("no custom_fields in \{issue.stringify()}")
  }
  for field in fields {
    if field is { "id": Number(found, ..), "value": value, .. } &&
      found.to_int() == id {
      return value
    }
  }
  fail("custom field \{id} missing from \{issue.stringify()}")
}

///|
async test "live: an issue is created with a required custom field and its multi-value field is emptied" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = @redmine.new(endpoint~, api_key~)
  let tools = [issues_tool(redmine, Full)]
  guard @redmine.send(redmine, Get, ["projects", "demo-custom-fields.json"])
    is { "project": { "id": Number(project_id, ..), .. }, .. } else {
    fail("project demo-custom-fields is not seeded; run `task redmine:seed`")
  }
  let severity = seeded_custom_field(redmine, "Severity")
  let platforms = seeded_custom_field(redmine, "Platforms")
  let issue : Json = {
    "project_id": project_id,
    "tracker_id": 1,
    "status_id": 1,
    "priority_id": 2,
    "subject": "redmoon-custom-fields-\{@env.now()}",
  }
  let refused = call_tool(tools, "redmine_issues", { "create": issue })
  assert_eq(refused.is_error, true, msg=refused.text)
  assert_true(refused.text.contains("Severity"), msg=refused.text)
  let created = call_tool(tools, "redmine_issues", {
    "create": with_field(issue, "custom_fields", [
      { "id": severity, "value": "high" },
      { "id": platforms, "value": ["linux", "macos"] },
    ]),
  })
  assert_eq(created.is_error, false, msg=created.text)
  let body = @json.parse(created.text)
  guard body is { "id": Number(id, ..), .. } else {
    fail("no id in \{created.text}")
  }
  let id = id.to_int()
  defer ignore(call_tool(tools, "redmine_issues", { "delete": { "id": id } }))
  assert_eq(custom_field_value(body, severity), "high")
  assert_eq(custom_field_value(body, platforms), ["linux", "macos"])
  let emptied = call_tool(tools, "redmine_issues", {
    "update": { "id": id, "custom_fields": [{ "id": platforms, "value": [] }] },
  })
  assert_eq(emptied.text, "{\"ok\":true}")
  let shown = call_tool(tools, "redmine_issues", { "show": { "id": id } })
  let shown = @json.parse(shown.text)
  assert_eq(custom_field_value(shown, platforms), [])
  assert_eq(custom_field_value(shown, severity), "high")
}

///|
async test "tools/list advertises the issues tool in both modes" {
  let advertised = []
  for mode in [Mode::Full, Readonly] {
    advertised.push(
      list_tools([issues_tool(FakeIssues::new(), mode)]).stringify(),
    )
  }
  assert_eq(
    advertised[0],
    "{\"tools\":[{\"name\":\"redmine_issues\",\"description\":\"Create, read, update, and delete Redmine issues. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\\n`show` returns the bare issue; pass `include: [\\\"journals\\\"]` to get its comments and field-change history, and add `attachments`, `relations`, `children`, `changesets`, `watchers`, or `allowedStatuses` as needed.\\n`list` accepts only `attachments` and `relations`.\\n`update_note` edits the text or privacy of an existing comment, and `delete_note` erases its text; both take the journal id that `show` lists.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"include\":{\"type\":\"array\",\"items\":{\"type\":\"string\",\"enum\":[\"attachments\",\"relations\"]},\"description\":\"Associations Redmine omits unless asked for. A listed issue carries only these two; `journals` are available through `show`.\"},\"project_id\":{\"type\":\"integer\",\"minimum\":1},\"tracker_id\":{\"type\":\"integer\",\"minimum\":1},\"status_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"enum\":[\"open\",\"closed\",\"*\"]}]},\"fixed_version_id\":{\"type\":\"integer\",\"minimum\":1},\"assigned_to_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"enum\":[\"me\"]}]},\"start_date\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"},{\"type\":\"string\",\"enum\":[\"tomorrow\",\"nextWeek\",\"nextMonth\"]},{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false,\"description\":\"The single day that many days from now.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after the day n days from now.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days from now.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"const\":\"today\"},\"to\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"from\",\"to\"],\"additionalProperties\":false,\"description\":\"The next n days: today through the day n days from now.\"}]},\"due_date\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"},{\"type\":\"string\",\"enum\":[\"tomorrow\",\"nextWeek\",\"nextMonth\"]},{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false,\"description\":\"The single day that many days from now.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after the day n days from now.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days from now.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"const\":\"today\"},\"to\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"from\",\"to\"],\"additionalProperties\":false,\"description\":\"The next n days: today through the day n days from now.\"}]},\"created_on\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"}]},\"updated_on\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"}]},\"closed_on\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"}]},\"limit\":{\"type\":\"integer\",\"minimum\":1}},\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1},\"include\":{\"type\":\"array\",\"items\":{\"type\":\"string\",\"enum\":[\"journals\",\"attachments\",\"relations\",\"children\",\"changesets\",\"watchers\",\"allowedStatuses\"]},\"description\":\"Associations Redmine omits unless asked for. `journals` are the comments and the field-change history.\"}},\"required\":[\"id\"],\"additionalProperties\":false},\"create\":{\"type\":\"object\",\"properties\":{\"project_id\":{\"type\":\"integer\",\"minimum\":1},\"tracker_id\":{\"type\":\"integer\",\"minimum\":1},\"status_id\":{\"type\":\"integer\",\"minimum\":1},\"priority_id\":{\"type\":\"integer\",\"minimum\":1},\"subject\":{\"type\":\"string\"},\"description\":{\"type\":\"string\"},\"fixed_version_id\":{\"type\":\"integer\",\"minimum\":1},\"assigned_to_id\":{\"type\":\"integer\",\"minimum\":1},\"parent_issue_id\":{\"type\":\"integer\",\"minimum\":1},\"start_date\":{\"type\":\"string\",\"format\":\"date\",\"description\":\"Day the issue starts, as an ISO date (`YYYY-MM-DD`). This is the date to write, not a filter: unlike `start_date` on `list`, no period or range is accepted here.\"},\"due_date\":{\"type\":\"string\",\"format\":\"date\",\"description\":\"Day the issue is due, as an ISO date (`YYYY-MM-DD`). This is the date to write, not a filter: unlike `due_date` on `list`, no period or range is accepted here.\"},\"is_private\":{\"type\":\"boolean\"},\"estimated_hours\":{\"type\":\"number\"},\"custom_fields\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1},\"value\":{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"array\",\"items\":{\"type\":\"string\"}}]}},\"required\":[\"id\",\"value\"],\"additionalProperties\":false},\"description\":\"Custom field values, each naming its field by id; `show` on an issue of the same project and tracker lists the fields and their ids under `custom_fields`. Every value is text, even for a number or checkbox field (`\\\"3\\\"`, `\\\"1\\\"` for checked), and a multi-value field takes an array of strings. `\\\"\\\"` empties a field.\"}},\"required\":[\"project_id\",\"tracker_id\",\"status_id\",\"priority_id\",\"subject\"],\"additionalProperties\":false},\"update\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1},\"subject\":{\"type\":\"string\"},\"description\":{\"type\":\"string\"},\"status_id\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Status to move the issue to. Redmine ignores, without an error, a status the workflow does not allow; `show` with `include: [\\\"allowedStatuses\\\"]` lists the ones it does.\"},\"priority_id\":{\"type\":\"integer\",\"minimum\":1},\"tracker_id\":{\"type\":\"integer\",\"minimum\":1},\"assigned_to_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"null\"}],\"description\":\"User to assign the issue to; `null` unassigns it.\"},\"category_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"null\"}],\"description\":\"Issue category to file the issue under; `null` removes the category.\"},\"parent_issue_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"null\"}],\"description\":\"Issue to make the parent of this one; `null` detaches it from its parent.\"},\"fixed_version_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"null\"}],\"description\":\"Version to move the issue into; `null` takes it out of its version.\"},\"start_date\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\"},{\"type\":\"null\"}],\"description\":\"Day the issue starts, as an ISO date (`YYYY-MM-DD`); `null` clears the date. This is the date to write, not a filter: unlike `start_date` on `list`, no period or range is accepted here.\"},\"due_date\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\"},{\"type\":\"null\"}],\"description\":\"Day the issue is due, as an ISO date (`YYYY-MM-DD`); `null` clears the date. This is the date to write, not a filter: unlike `due_date` on `list`, no period or range is accepted here.\"},\"done_ratio\":{\"type\":\"integer\",\"minimum\":0,\"maximum\":100},\"is_private\":{\"type\":\"boolean\"},\"estimated_hours\":{\"type\":\"number\"},\"notes\":{\"type\":\"string\"},\"private_notes\":{\"type\":\"boolean\"},\"custom_fields\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1},\"value\":{\"anyOf\":[{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"array\",\"items\":{\"type\":\"string\"}}]},{\"type\":\"null\"}]}},\"required\":[\"id\",\"value\"],\"additionalProperties\":false},\"description\":\"Custom field values, each naming its field by id; `show` on an issue of the same project and tracker lists the fields and their ids under `custom_fields`. Every value is text, even for a number or checkbox field (`\\\"3\\\"`, `\\\"1\\\"` for checked), and a multi-value field takes an array of strings. `\\\"\\\"` empties a field.\"}},\"required\":[\"id\"],\"additionalProperties\":false},\"delete\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false},\"update_note\":{\"anyOf\":[{\"type\":\"object\",\"properties\":{\"journal_id\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Id of the comment (journal), as listed by `show` with `include: [\\\"journals\\\"]`.\"},\"notes\":{\"type\":\"string\",\"minLength\":1,\"description\":\"New text of the comment. To erase it, use `delete_note`.\"},\"private_notes\":{\"type\":\"boolean\"}},\"required\":[\"journal_id\",\"notes\"],\"additionalProperties\":false},{\"type\":\"object\",\"properties\":{\"journal_id\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Id of the comment (journal), as listed by `show` with `include: [\\\"journals\\\"]`.\"},\"private_notes\":{\"type\":\"boolean\"}},\"required\":[\"journal_id\",\"private_notes\"],\"additionalProperties\":false}]},\"delete_note\":{\"type\":\"object\",\"properties\":{\"journal_id\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Id of the comment (journal), as listed by `show` with `include: [\\\"journals\\\"]`.\"}},\"required\":[\"journal_id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
  assert_eq(
    advertised[1],
    "{\"tools\":[{\"name\":\"redmine_issues\",\"description\":\"List and show Redmine issues. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\\\"<operation>\\\": {...}}`.\\n`show` returns the bare issue; pass `include: [\\\"journals\\\"]` to get its comments and field-change history, and add `attachments`, `relations`, `children`, `changesets`, `watchers`, or `allowedStatuses` as needed.\\n`list` accepts only `attachments` and `relations`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"include\":{\"type\":\"array\",\"items\":{\"type\":\"string\",\"enum\":[\"attachments\",\"relations\"]},\"description\":\"Associations Redmine omits unless asked for. A listed issue carries only these two; `journals` are available through `show`.\"},\"project_id\":{\"type\":\"integer\",\"minimum\":1},\"tracker_id\":{\"type\":\"integer\",\"minimum\":1},\"status_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"enum\":[\"open\",\"closed\",\"*\"]}]},\"fixed_version_id\":{\"type\":\"integer\",\"minimum\":1},\"assigned_to_id\":{\"anyOf\":[{\"type\":\"integer\",\"minimum\":1},{\"type\":\"string\",\"enum\":[\"me\"]}]},\"start_date\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"},{\"type\":\"string\",\"enum\":[\"tomorrow\",\"nextWeek\",\"nextMonth\"]},{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false,\"description\":\"The single day that many days from now.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after the day n days from now.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days from now.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"const\":\"today\"},\"to\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"from\",\"to\"],\"additionalProperties\":false,\"description\":\"The next n days: today through the day n days from now.\"}]},\"due_date\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"},{\"type\":\"string\",\"enum\":[\"tomorrow\",\"nextWeek\",\"nextMonth\"]},{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false,\"description\":\"The single day that many days from now.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after the day n days from now.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days from now.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"const\":\"today\"},\"to\":{\"type\":\"object\",\"properties\":{\"days_from_now\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_from_now\"],\"additionalProperties\":false}},\"required\":[\"from\",\"to\"],\"additionalProperties\":false,\"description\":\"The next n days: today through the day n days from now.\"}]},\"created_on\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"}]},\"updated_on\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"}]},\"closed_on\":{\"anyOf\":[{\"type\":\"string\",\"format\":\"date\",\"description\":\"That day.\"},{\"type\":\"string\",\"enum\":[\"today\",\"yesterday\",\"thisWeek\",\"lastWeek\",\"lastTwoWeeks\",\"thisMonth\",\"lastMonth\",\"thisYear\",\"any\",\"none\"]},{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false,\"description\":\"The single day that many days ago.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"On or after `from`, and on or before `to` when it is given.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\",\"format\":\"date\"},\"to\":{\"type\":\"string\",\"format\":\"date\"}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before `to`.\"},{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false},\"to\":{\"type\":\"string\",\"const\":\"today\"}},\"required\":[\"from\"],\"additionalProperties\":false,\"description\":\"The last n days: on or after the day n days ago.\"},{\"type\":\"object\",\"properties\":{\"to\":{\"type\":\"object\",\"properties\":{\"days_ago\":{\"type\":\"integer\",\"minimum\":0}},\"required\":[\"days_ago\"],\"additionalProperties\":false}},\"required\":[\"to\"],\"additionalProperties\":false,\"description\":\"On or before the day n days ago.\"}]},\"limit\":{\"type\":\"integer\",\"minimum\":1}},\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1},\"include\":{\"type\":\"array\",\"items\":{\"type\":\"string\",\"enum\":[\"journals\",\"attachments\",\"relations\",\"children\",\"changesets\",\"watchers\",\"allowedStatuses\"]},\"description\":\"Associations Redmine omits unless asked for. `journals` are the comments and the field-change history.\"}},\"required\":[\"id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "list rejects a limit below 1, which would answer without asking Redmine" {
  assert_eq(
    rejected("list", { "limit": 0 }),
    "{\"status\":0,\"errors\":[\"invalid arguments: list.limit: must be at least 1\"]}",
  )
  assert_eq(
    rejected("list", { "limit": -3 }),
    "{\"status\":0,\"errors\":[\"invalid arguments: list.limit: must be at least 1\"]}",
  )
}

///|
async test "update rejects a done_ratio outside 0 to 100" {
  assert_eq(
    rejected("update", { "id": 1, "done_ratio": -1 }),
    "{\"status\":0,\"errors\":[\"invalid arguments: update.done_ratio: must be at least 0\"]}",
  )
  assert_eq(
    rejected("update", { "id": 1, "done_ratio": 150 }),
    "{\"status\":0,\"errors\":[\"invalid arguments: update.done_ratio: must be at most 100\"]}",
  )
}

///|
async test "update accepts the done_ratio bounds" {
  assert_eq(updated_with({ "id": 1, "done_ratio": 0 }).done_ratio, Some(0))
  assert_eq(updated_with({ "id": 1, "done_ratio": 100 }).done_ratio, Some(100))
}
