///|
test "time entry list query names only the filters that are set" {
  let query : TimeEntryListQuery = {
    project_id: Some(1),
    user_id: None,
    spent_on: None,
    from: Some("2026-10-01"),
    to: Some("2026-10-31"),
  }
  inspect(
    encode_query(query.to_pairs()),
    content="project_id=1&from=2026-10-01&to=2026-10-31",
  )
}

///|
test "time entry list query with no filters sends no parameters" {
  let query : TimeEntryListQuery = {
    project_id: None,
    user_id: None,
    spent_on: None,
    from: None,
    to: None,
  }
  inspect(encode_query(query.to_pairs()), content="")
}
