///|
fn row(
  story_points? : Int32,
  agile_sprint_id? : Int32,
  position? : Int32,
) -> AgileData {
  { id: 9, issue_id: 42, story_points, agile_sprint_id, position, }
}

///|
test "an agile_data answer decodes without the members its view rendered as null" {
  let json = @json.parse(
    (
      #|{"agile_data":{"id":9,"issue_id":42,"position":2,"story_points":3,"color":"red"}}
    ),
  )
  let decoded : AgileData = @decode.decode_field(json, "agile_data") catch {
    _ => fail("decode")
  }
  assert_eq(decoded, row(story_points=3, position=2))
}

///|
test "an agile_data answer without its row id fails to decode" {
  try @json.from_json(Json::object({ "issue_id": 42 })) catch {
    _ => ()
  } noraise {
    (_ : AgileData) => fail("expected a decode error")
  }
}

///|
test "agile data encodes under the plugin's keys, leaving unset fields out" {
  assert_eq(
    row(agile_sprint_id=5).to_json().stringify(),
    "{\"id\":9,\"issue_id\":42,\"agile_sprint_id\":5}",
  )
}

///|
test "an update carries the row id and its values forward and overlays the change" {
  let current = row(story_points=3, agile_sprint_id=2, position=5)
  let body = Update::new(agile_sprint_id=Set(117)).to_body(Some(current))
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"agile_data_attributes\":{\"id\":9,\"story_points\":3,\"agile_sprint_id\":117,\"position\":5}}}",
  )
}

///|
test "an update leaves out the fields the row does not hold" {
  let body = Update::new(position=Set(1)).to_body(Some(row(story_points=3)))
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"agile_data_attributes\":{\"id\":9,\"story_points\":3,\"position\":1}}}",
  )
}

///|
test "an update of an issue without a row sends only the requested fields" {
  let body = Update::new(story_points=Set(8)).to_body(None)
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"agile_data_attributes\":{\"story_points\":8}}}",
  )
}

///|
test "Clear is sent as null and wins over the value the row holds" {
  let current = row(story_points=3, agile_sprint_id=2, position=5)
  let body = Update::new(story_points=Clear, agile_sprint_id=Clear).to_body(
    Some(current),
  )
  assert_eq(
    body.stringify(),
    "{\"issue\":{\"agile_data_attributes\":{\"id\":9,\"story_points\":null,\"agile_sprint_id\":null,\"position\":5}}}",
  )
}

///|
async test "a 404 from the read means the issue has no row yet" {
  let missing = or_missing(fn() -> AgileData raise @redmine.RedmineError {
    raise @redmine.Response(status=404, errors=[])
  })
  assert_eq(missing, None)
  let found = or_missing(() => row())
  assert_eq(found, Some(row()))
}

///|
async test "any other failure of the read is raised rather than taken for a missing row" {
  for
    error in [
      @redmine.Response(status=403, errors=[]),
      @redmine.Transport(message="connection refused"),
    ] {
    try
      or_missing(fn() -> AgileData raise @redmine.RedmineError { raise error })
    catch {
      raised => assert_eq(Json(raised), Json(error))
    } noraise {
      _ => fail("a failed read must not be taken for a missing row")
    }
  }
}
