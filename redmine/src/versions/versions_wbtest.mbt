///|
test "a create body carries the name and leaves unset fields out" {
  assert_eq(
    Create::new(name="v1").to_body().stringify(),
    "{\"version\":{\"name\":\"v1\"}}",
  )
}

///|
test "an update body leaves unset fields out" {
  assert_eq(
    Update::new(
      description=Set("d"),
      status=Locked,
      due_date=Set("2026-12-31"),
      sharing=Tree,
      wiki_page_title=Set("Home"),
    )
    .to_body()
    .stringify(),
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
  let version : Version = @decode.decode_field(
    @wire.strip_nulls(json),
    "version",
  ) catch {
    _ => fail("decode")
  }
  assert_eq(version.status, Open)
  assert_eq(version.sharing, None)
  assert_eq(version.due_date, None)
  assert_eq(version.description, Some(""))
}

///|
test "an unknown version status fails to decode naming the wire value" {
  try @json.from_json(Json("done")) catch {
    @json.JsonDecodeError((_, reason)) =>
      assert_eq(reason, "Status::from_json: unknown version status `done`")
  } noraise {
    (_ : Status) => fail("expected a decode error")
  }
}

///|
test "an unknown version sharing fails to decode naming the wire value" {
  try @json.from_json(Json("galaxy")) catch {
    @json.JsonDecodeError((_, reason)) =>
      assert_eq(reason, "Sharing::from_json: unknown version sharing `galaxy`")
  } noraise {
    (_ : Sharing) => fail("expected a decode error")
  }
}

///|
test "an update body sends null for a cleared field" {
  assert_eq(
    Update::new(due_date=Clear, wiki_page_title=Clear, description=Clear)
    .to_body()
    .stringify(),
    "{\"version\":{\"description\":null,\"due_date\":null,\"wiki_page_title\":null}}",
  )
}
