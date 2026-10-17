///|
test "past date filters encode to Redmine operators" {
  let cases : Array[(PastDateFilter, String)] = [
    (On("2026-07-01"), "=2026-07-01"),
    (Period(Today), "t"),
    (Period(Yesterday), "ld"),
    (Period(ThisWeek), "w"),
    (Period(LastWeek), "lw"),
    (Period(LastTwoWeeks), "l2w"),
    (Period(ThisMonth), "m"),
    (Period(LastMonth), "lm"),
    (Period(ThisYear), "y"),
    (Period(Any), "*"),
    (Period(Blank), "!*"),
    (Between(from="2026-07-01", to="2026-07-31"), "><2026-07-01|2026-07-31"),
    (Since("2026-07-01"), ">=2026-07-01"),
    (Until("2026-07-31"), "<=2026-07-31"),
    (DaysAgo(3), "t-3"),
    (DaysAgo(0), "t-0"),
    (SinceDaysAgo(3), ">t-3"),
    (LastDays(3), "><t-3"),
    (UntilDaysAgo(3), "<t-3"),
  ]
  for case in cases {
    assert_eq(case.0.query_value(), case.1)
  }
}

///|
test "date filters add the forward-looking operators" {
  let cases : Array[(DateFilter, String)] = [
    (Past(On("2026-07-01")), "=2026-07-01"),
    (Past(Period(Blank)), "!*"),
    (Past(LastDays(7)), "><t-7"),
    (Tomorrow, "nd"),
    (NextWeek, "nw"),
    (NextMonth, "nm"),
    (DaysFromNow(5), "t+5"),
    (SinceDaysFromNow(5), ">t+5"),
    (UntilDaysFromNow(5), "<t+5"),
    (NextDays(5), "><t+5"),
  ]
  for case in cases {
    assert_eq(case.0.query_value(), case.1)
  }
}

///|
test "an empty list query sends nothing" {
  @debug.debug_inspect(ListQuery::new().to_query(), content="[]")
}

///|
test "a list query encodes every condition in a fixed order" {
  let query = ListQuery::new(
    includes=[Relations, Attachments, Relations],
    project_id=1,
    tracker_id=2,
    status_id=Open,
    fixed_version_id=3,
    assigned_to_id=Me,
    start_date=Past(On("2026-01-01")),
    due_date=NextDays(4),
    created_on=Period(Today),
    updated_on=LastDays(2),
    closed_on=Period(Any),
  )
  @debug.debug_inspect(
    query.to_query(),
    content=(
      #|[
      #|  ("include", "relations,attachments"),
      #|  ("project_id", "1"),
      #|  ("tracker_id", "2"),
      #|  ("status_id", "open"),
      #|  ("fixed_version_id", "3"),
      #|  ("assigned_to_id", "me"),
      #|  ("start_date", "=2026-01-01"),
      #|  ("due_date", "><t+4"),
      #|  ("created_on", "t"),
      #|  ("updated_on", "><t-2"),
      #|  ("closed_on", "*"),
      #|]
    ),
  )
}

///|
test "status and assignee filters encode ids and keywords" {
  assert_eq(StatusFilter::Id(5).query_value(), "5")
  assert_eq(StatusFilter::Closed.query_value(), "closed")
  assert_eq(StatusFilter::All.query_value(), "*")
  assert_eq(AssigneeFilter::User(9).query_value(), "9")
}

///|
test "create body carries only the fields that are set" {
  let body = Create::new(
    project_id=1,
    tracker_id=1,
    status_id=1,
    priority_id=2,
    subject="s",
  ).to_body()
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"project_id\":1,\"tracker_id\":1,\"status_id\":1,\"priority_id\":2,\"subject\":\"s\"}}",
  )
}

///|
test "create body carries every optional field" {
  let body = Create::new(
    project_id=1,
    tracker_id=1,
    status_id=1,
    priority_id=2,
    subject="s",
    description="d",
    category_id=4,
    fixed_version_id=5,
    assigned_to_id=6,
    parent_issue_id=7,
    watcher_user_ids=[8, 9],
    is_private=true,
    estimated_hours=1.5,
    start_date="2026-01-01",
    due_date="2026-01-31",
    custom_fields=[
      { id: 1, value: Single("a"), },
      { id: 2, value: Multiple(["b", "c"]), },
    ],
    uploads=[
      UploadToken::new("tok", filename="f.txt", content_type="text/plain"),
    ],
  ).to_body()
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"project_id\":1,\"tracker_id\":1,\"status_id\":1,\"priority_id\":2,\"subject\":\"s\",\"description\":\"d\",\"category_id\":4,\"fixed_version_id\":5,\"assigned_to_id\":6,\"parent_issue_id\":7,\"watcher_user_ids\":[8,9],\"is_private\":true,\"estimated_hours\":1.5,\"start_date\":\"2026-01-01\",\"due_date\":\"2026-01-31\",\"custom_fields\":[{\"id\":1,\"value\":\"a\"},{\"id\":2,\"value\":[\"b\",\"c\"]}],\"uploads\":[{\"token\":\"tok\",\"filename\":\"f.txt\",\"content_type\":\"text/plain\"}]}}",
  )
}

///|
test "an empty update sends an empty issue" {
  assert_eq(Update::new().to_body().stringify(), "{\"issue\":{}}")
}

///|
test "update body sends plain fields as given" {
  let body = Update::new(
    subject="s",
    description="d",
    notes="n",
    private_notes=true,
    done_ratio=50,
    is_private=false,
    estimated_hours=2.0,
    status_id=2,
    priority_id=3,
    tracker_id=1,
    custom_fields=[{ id: 1, value: Single("a"), }],
    uploads=[UploadToken::new("tok", description="d")],
  ).to_body()
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"subject\":\"s\",\"description\":\"d\",\"notes\":\"n\",\"private_notes\":true,\"done_ratio\":50,\"is_private\":false,\"estimated_hours\":2,\"status_id\":2,\"priority_id\":3,\"tracker_id\":1,\"custom_fields\":[{\"id\":1,\"value\":\"a\"}],\"uploads\":[{\"token\":\"tok\",\"description\":\"d\"}]}}",
  )
}

///|
test "update body sets clearable fields" {
  let body = Update::new(
    assigned_to_id=Set(1),
    category_id=Set(2),
    parent_issue_id=Set(3),
    fixed_version_id=Set(4),
    start_date=Set("2026-01-01"),
    due_date=Set("2026-01-31"),
  ).to_body()
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"assigned_to_id\":1,\"category_id\":2,\"parent_issue_id\":3,\"fixed_version_id\":4,\"start_date\":\"2026-01-01\",\"due_date\":\"2026-01-31\"}}",
  )
}

///|
test "update body clears with null, except the assignee which needs a blank string" {
  let body = Update::new(
    assigned_to_id=Clear,
    category_id=Clear,
    parent_issue_id=Clear,
    fixed_version_id=Clear,
    start_date=Clear,
    due_date=Clear,
  ).to_body()
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"assigned_to_id\":\"\",\"category_id\":null,\"parent_issue_id\":null,\"fixed_version_id\":null,\"start_date\":null,\"due_date\":null}}",
  )
}

///|
test "include values use Redmine's names and drop repeats" {
  let names = [Journals, AllowedStatuses, Children, Journals].map(Include::name)
  assert_eq(include_value(names), "journals,allowed_statuses,children")
}

///|
test "a listed issue decodes" {
  let text =
    #|{"id":3,"project":{"id":1,"name":"Demo"},"tracker":{"id":1,"name":"Bug"},"status":{"id":1,"name":"New","is_closed":false},"priority":{"id":2,"name":"Normal"},"author":{"id":1,"name":"Redmine Admin"},"subject":"s","description":null,"start_date":null,"due_date":null,"done_ratio":0,"is_private":false,"estimated_hours":null,"total_estimated_hours":null,"spent_hours":0.0,"total_spent_hours":0.0,"created_on":"2026-10-15T18:08:53Z","updated_on":"2026-10-15T18:08:53Z","closed_on":null}
  let json = @wire.strip_nulls(@json.parse(text))
  let issue : Issue = @decode.decode(json)
  assert_eq(issue.id, 3)
  assert_eq(issue.subject, "s")
  assert_eq(issue.status.is_closed, Some(false))
  assert_eq(issue.description, None)
  assert_eq(issue.spent_hours, Some(0.0))
  assert_eq(issue.journals, None)
}

///|
test "a shown issue decodes every include" {
  let text =
    #|{"id":1,"project":{"id":1,"name":"Demo"},"tracker":{"id":1,"name":"Bug"},"status":{"id":1,"name":"New","is_closed":false},"priority":{"id":2,"name":"Normal"},"author":{"id":1,"name":"Redmine Admin"},"assigned_to":{"id":1,"name":"Redmine Admin"},"parent":{"id":9},"subject":"s","description":"d","start_date":"2026-01-01","due_date":"2026-01-31","done_ratio":10,"is_private":false,"estimated_hours":1.5,"created_on":"2026-10-15T17:56:29Z","updated_on":"2026-10-15T17:56:29Z","closed_on":null,
    #|"custom_fields":[{"id":1,"name":"A","value":"x"},{"id":2,"name":"B","multiple":true,"value":["y","z"]},{"id":3,"name":"C","value":null}],
    #|"attachments":[{"id":4,"filename":"f.txt","filesize":12,"content_type":"text/plain","description":"","content_url":"http://localhost:3000/attachments/download/4/f.txt","author":{"id":1,"name":"Redmine Admin"},"created_on":"2026-10-15T17:56:29Z"}],
    #|"relations":[{"id":5,"issue_id":1,"issue_to_id":2,"relation_type":"relates","delay":null}],
    #|"children":[{"id":6,"tracker":{"id":1,"name":"Bug"},"subject":"c"}],
    #|"changesets":[],
    #|"journals":[{"id":7,"user":{"id":1,"name":"Redmine Admin"},"notes":"hello","created_on":"2026-10-15T17:56:29Z","private_notes":false,"details":[{"property":"attr","name":"status_id","old_value":"1","new_value":"2"}]}],
    #|"watchers":[{"id":1,"name":"Redmine Admin"}],
    #|"allowed_statuses":[{"id":1,"name":"New","is_closed":false}]}
  let json = @wire.strip_nulls(@json.parse(text))
  let issue : Issue = @decode.decode(json)
  assert_eq(issue.parent, Some({ id: 9, }))
  assert_eq(issue.estimated_hours, Some(1.5))
  assert_eq(
    issue.custom_fields,
    Some([
      { id: 1, name: "A", value: Some(Single("x")), multiple: None, },
      {
        id: 2,
        name: "B",
        value: Some(Multiple(["y", "z"])),
        multiple: Some(true),
      },
      { id: 3, name: "C", value: None, multiple: None, },
    ]),
  )
  assert_eq(issue.attachments.unwrap()[0].filesize, 12)
  assert_eq(issue.relations.unwrap()[0].delay, None)
  assert_eq(issue.children.unwrap()[0].subject, "c")
  let journal = issue.journals.unwrap()[0]
  assert_eq(journal.notes, Some("hello"))
  assert_eq(journal.details[0].old_value, Some("1"))
  assert_eq(issue.watchers.unwrap().length(), 1)
  assert_eq(issue.allowed_statuses.unwrap()[0].is_closed, Some(false))
}

///|
test "an attachment of a shown issue is an attachments Attachment" {
  let text =
    #|{"id":1,"project":{"id":1,"name":"Demo"},"tracker":{"id":1,"name":"Bug"},"status":{"id":1,"name":"New"},"priority":{"id":2,"name":"Normal"},"author":{"id":1,"name":"Redmine Admin"},"subject":"s","created_on":"2026-10-15T17:56:29Z","updated_on":"2026-10-15T17:56:29Z",
    #|"attachments":[{"id":4,"filename":"f.txt","filesize":12,"content_type":"text/plain","content_url":"http://localhost:3000/attachments/download/4/f.txt","author":{"id":1,"name":"Redmine Admin"},"created_on":"2026-10-15T17:56:29Z"}]}
  let issue : Issue = @decode.decode(@wire.strip_nulls(@json.parse(text)))
  let attachment : @attachments.Attachment = issue.attachments.unwrap()[0]
  assert_eq(attachment.filename, "f.txt")
}
