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
test "an update carries the row id and held values forward under the requested changes" {
  let full = row(story_points=3, agile_sprint_id=2, position=5)
  let cases : Array[(Update, AgileData?, String)] = [
    (
      Update::new(agile_sprint_id=Set(117)),
      Some(full),
      "{\"id\":9,\"story_points\":3,\"agile_sprint_id\":117,\"position\":5}",
    ),
    (
      Update::new(position=Set(1)),
      Some(row(story_points=3)),
      "{\"id\":9,\"story_points\":3,\"position\":1}",
    ),
    (Update::new(story_points=Set(8)), None, "{\"story_points\":8}"),
    (
      Update::new(story_points=Clear, agile_sprint_id=Clear),
      Some(full),
      "{\"id\":9,\"story_points\":null,\"agile_sprint_id\":null,\"position\":5}",
    ),
  ]
  for entry in cases {
    assert_eq(
      entry.0.to_body(entry.1).stringify(),
      "{\"issue\":{\"agile_data_attributes\":\{entry.2}}}",
    )
  }
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
