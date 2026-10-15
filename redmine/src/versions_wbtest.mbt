///|
test "version body leaves unset fields out" {
  assert_eq(
    version_body(Some("v1"), None, None, None, None, None).stringify(),
    "{\"version\":{\"name\":\"v1\"}}",
  )
  assert_eq(
    version_body(
      None,
      Some("d"),
      Some(Locked),
      Some("2026-12-31"),
      Some(Tree),
      Some("Home"),
    ).stringify(),
    "{\"version\":{\"description\":\"d\",\"status\":\"locked\",\"due_date\":\"2026-12-31\",\"sharing\":\"tree\",\"wiki_page_title\":\"Home\"}}",
  )
}

///|
test "a version decodes from a Redmine response" {
  let json = @json.parse(
    (
      #|{"version":{"id":1,"project":{"id":1,"name":"Demo"},"name":"v1","description":"","status":"open","due_date":null,"sharing":"none","wiki_page_title":null,"estimated_hours":0.0,"spent_hours":0.0,"created_on":"2026-10-15T18:06:44Z","updated_on":"2026-10-15T18:06:44Z"}}
    ),
  )
  let version : Version = decode_field(strip_nulls(json), "version") catch {
    _ => fail("decode")
  }
  assert_eq(version.status, Open)
  assert_eq(version.sharing, None)
  assert_eq(version.due_date, None)
  assert_eq(version.description, Some(""))
}

///|
test "an unknown version status fails to decode" {
  try @json.from_json(Json("done")) catch {
    _ => ()
  } noraise {
    (_ : VersionStatus) => fail("expected a decode error")
  }
}
