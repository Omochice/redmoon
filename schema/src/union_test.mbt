///|
enum DayBound {
  Days(Int32)
  Period(String)
} derive(Debug)

///|
let day_bound : Schema[DayBound] = union([
  integer(min=0).map(n => Days(n)),
  picklist(["today", "any"]).map(s => Period(s)),
])

///|
test "nullable emits anyOf with null" {
  assert_eq(
    schema_json(nullable(integer())),
    "{\"anyOf\":[{\"type\":\"integer\"},{\"type\":\"null\"}]}",
  )
}

///|
test "nullable parses null to None" {
  let s = nullable(integer(min=1))
  assert_eq(outcome(s, "null"), "ok: None")
  assert_eq(outcome(s, "3"), "ok: Some(3)")
  assert_eq(outcome(s, "0"), "error: must be at least 1")
  assert_eq(outcome(s, "\"x\""), "error: expected an integer")
}

///|
test "nullable inside an object keeps absent and null apart" {
  let a = @schema.optional("a", nullable(integer()))
  let s = @schema.record([a.as_member()], v => v.get(a))
  assert_eq(outcome(s, "{}"), "ok: None")
  assert_eq(outcome(s, "{\"a\":null}"), "ok: Some(None)")
  assert_eq(outcome(s, "{\"a\":2}"), "ok: Some(Some(2))")
  assert_eq(outcome(s, "{\"a\":\"x\"}"), "error: a: expected an integer")
}

///|
test "union emits anyOf in order" {
  assert_eq(
    schema_json(day_bound),
    "{\"anyOf\":[{\"type\":\"integer\",\"minimum\":0},{\"type\":\"string\",\"enum\":[\"today\",\"any\"]}]}",
  )
}

///|
test "union parses with the first matching alternative" {
  assert_eq(outcome(day_bound, "3"), "ok: Days(3)")
  assert_eq(outcome(day_bound, "\"any\""), "ok: Period(\"any\")")
}

///|
test "union lists alternatives when none matches" {
  assert_eq(
    outcome(day_bound, "true"),
    "error: no alternative matched: expected an integer; must be one of today, any",
  )
  assert_eq(
    outcome(day_bound, "-1"),
    "error: no alternative matched: must be at least 0; must be one of today, any",
  )
}

///|
test "union of objects reports field errors" {
  let id = @schema.required("id", integer())
  let name = @schema.required("name", string())
  let by_id = @schema.record([id.as_member()], v => v.get(id))
  let by_name = @schema.record([name.as_member()], v => v.get(name))
  let s = union([by_id.map(id => id.to_string()), by_name])
  assert_eq(outcome(s, "{\"id\":4}"), "ok: \"4\"")
  assert_eq(outcome(s, "{\"name\":\"n\"}"), "ok: \"n\"")
  assert_eq(
    outcome(s, "{\"id\":\"x\"}"),
    "error: id: expected an integer; id: unknown field",
  )
  assert_eq(outcome(s, "{}"), "error: id: is required; name: is required")
  assert_eq(
    outcome(s, "{\"id\":1,\"name\":\"n\"}"),
    "error: name: unknown field; id: unknown field",
  )
  assert_eq(
    outcome(s, "3"),
    "error: no alternative matched: expected an object",
  )
}

///|
test "union errors carry the caller's path" {
  let id = @schema.required("id", integer())
  let s = @schema.record([id.as_member()], v => v.get(id))
  let u = union([s, s])
  let result = try u.parse_at(j("{}"), ["act"]) catch {
    e => e.message()
  } noraise {
    _ => "ok"
  }
  assert_eq(result, "act.id: is required")
}
