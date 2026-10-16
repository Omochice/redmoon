///|
test "time entry list query names only the filters that are set" {
  let query : ListQuery = {
    project_id: Some(1),
    user_id: None,
    spent_on: None,
    from: Some("2026-10-01"),
    to: Some("2026-10-31"),
  }
  inspect(
    @wire.encode_query(query.to_pairs()),
    content="project_id=1&from=2026-10-01&to=2026-10-31",
  )
}

///|
test "time entry list query with no filters sends no parameters" {
  let query : ListQuery = {
    project_id: None,
    user_id: None,
    spent_on: None,
    from: None,
    to: None,
  }
  inspect(@wire.encode_query(query.to_pairs()), content="")
}

///|
test "create body omits unset fields and wraps them in time_entry" {
  let create : Create = {
    hours: 1.5,
    issue_id: None,
    project_id: Some(1),
    spent_on: Some("2026-10-10"),
    activity_id: Some(8),
    comments: None,
  }
  inspect(
    entry_body(create).stringify(),
    content=(
      #|{"time_entry":{"hours":1.5,"project_id":1,"spent_on":"2026-10-10","activity_id":8}}
    ),
  )
}

///|
test "update body with only hours sends just that field" {
  let update : Update = {
    hours: Some(2.0),
    issue_id: None,
    project_id: None,
    spent_on: None,
    activity_id: None,
    comments: None,
  }
  inspect(
    entry_body(update).stringify(),
    content=(
      #|{"time_entry":{"hours":2}}
    ),
  )
}

///|
test "a time entry response decodes with an issue and null comments" {
  let text =
    #|{"time_entry":{"id":7,"project":{"id":1,"name":"Demo"},"issue":{"id":3},"user":{"id":1,"name":"Redmine Admin"},"activity":{"id":8,"name":"Design"},"hours":1.5,"comments":null,"spent_on":"2026-10-10","created_on":"2026-10-15T18:06:58Z","updated_on":"2026-10-15T18:06:58Z"}}
  let json = @wire.strip_nulls(@json.parse(text))
  let entry : Entry = @decode.decode_field(json, "time_entry") catch {
    _ => abort("decode failed")
  }
  assert_eq(entry.id, 7)
  assert_eq(entry.issue, Some({ id: 3, }))
  assert_eq(entry.comments, None)
  assert_eq(entry.hours, 1.5)
  assert_eq(entry.custom_fields, None)
}
