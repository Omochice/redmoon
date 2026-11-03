///|
let p_a : @schema.Field[Int32?] = @schema.optional("a", integer())

///|
let p_b : @schema.Field[Int32?] = @schema.optional("b", integer())

///|
let p_c : @schema.Field[Int32?] = @schema.optional("c", integer())

///|
let pair : Schema[(Int32?, Int32?)] = @schema.record(
  [p_a.as_member(), p_b.as_member()],
  v => (v.get(p_a), v.get(p_b)),
)

///|
let triple : Schema[(Int32?, Int32?, Int32?)] = @schema.record(
  [p_a.as_member(), p_b.as_member(), p_c.as_member()],
  v => (v.get(p_a), v.get(p_b), v.get(p_c)),
)

///|
let anything : Schema[Unit] = {
  json: () => { "type": "object" },
  decode: (_, _) => (),
}

///|
fn[T] outcome_at(schema : Schema[T], input : String) -> String {
  try (schema.decode)(j(input), ["act"]) catch {
    e => "error: " + e.message()
  } noraise {
    _ => "ok"
  }
}

///|
test "require_any accepts an object with at least one of the members" {
  let s = pair.require_any([p_a.as_member(), p_b.as_member()])
  assert_eq(outcome(s, "{\"a\":1}"), "ok: (Some(1), None)")
  assert_eq(outcome(s, "{\"b\":2}"), "ok: (None, Some(2))")
  assert_eq(outcome(s, "{\"a\":1,\"b\":2}"), "ok: (Some(1), Some(2))")
}

///|
test "require_any rejects an object without any of the members at the object" {
  let s = pair.require_any([p_a.as_member(), p_b.as_member()])
  assert_eq(outcome_at(s, "{}"), "error: act: one of `a` and `b` is required")
}

///|
test "require_one accepts an object with exactly one of the members" {
  let s = pair.require_one([p_a.as_member(), p_b.as_member()])
  assert_eq(outcome(s, "{\"a\":1}"), "ok: (Some(1), None)")
  assert_eq(outcome(s, "{\"b\":2}"), "ok: (None, Some(2))")
}

///|
test "require_one rejects none or several of the members at the object" {
  let s = pair.require_one([p_a.as_member(), p_b.as_member()])
  assert_eq(outcome_at(s, "{}"), "error: act: one of `a` and `b` is required")
  assert_eq(
    outcome_at(s, "{\"a\":1,\"b\":2}"),
    "error: act: `a` and `b` cannot be given together",
  )
}

///|
test "allow_one accepts an object with at most one of the members" {
  let s = pair.allow_one([p_a.as_member(), p_b.as_member()])
  assert_eq(outcome(s, "{}"), "ok: (None, None)")
  assert_eq(outcome(s, "{\"a\":1}"), "ok: (Some(1), None)")
  assert_eq(outcome(s, "{\"b\":2}"), "ok: (None, Some(2))")
}

///|
test "allow_one rejects several of the members at the object" {
  let s = pair.allow_one([p_a.as_member(), p_b.as_member()])
  assert_eq(
    outcome_at(s, "{\"a\":1,\"b\":2}"),
    "error: act: `a` and `b` cannot be given together",
  )
}

///|
test "a member is present when its key is, even with a null value" {
  let s = anything.allow_one([p_a.as_member(), p_b.as_member()])
  assert_eq(
    outcome_at(s, "{\"a\":null,\"b\":null}"),
    "error: act: `a` and `b` cannot be given together",
  )
  assert_eq(
    outcome(anything.require_any([p_a.as_member()]), "{\"a\":null}"),
    "ok: ()",
  )
}

///|
test "a combination of three or more members is listed in one sentence" {
  let members = [p_a.as_member(), p_b.as_member(), p_c.as_member()]
  assert_eq(
    outcome_at(triple.require_one(members), "{}"),
    "error: act: one of `a`, `b` and `c` is required",
  )
  assert_eq(
    outcome_at(triple.allow_one(members), "{\"a\":1,\"b\":2,\"c\":3}"),
    "error: act: `a`, `b` and `c` cannot be given together",
  )
  assert_eq(
    outcome_at(triple.require_one(members), "{\"a\":1,\"c\":3}"),
    "error: act: `a` and `c` cannot be given together",
  )
}

///|
test "the combination is checked before the wrapped schema decodes" {
  let s = pair.require_one([p_a.as_member(), p_b.as_member()])
  assert_eq(
    outcome_at(s, "{\"other\":1}"),
    "error: act: one of `a` and `b` is required",
  )
  assert_eq(
    outcome_at(s, "{\"a\":\"x\",\"b\":2}"),
    "error: act: `a` and `b` cannot be given together",
  )
  assert_eq(outcome_at(s, "{\"a\":\"x\"}"), "error: act.a: expected an integer")
}

///|
test "a non-object is left to the wrapped schema" {
  let members = [p_a.as_member(), p_b.as_member()]
  assert_eq(
    outcome(pair.require_one(members), "3"),
    "error: expected an object",
  )
  assert_eq(outcome(anything.require_any(members), "3"), "ok: ()")
  assert_eq(outcome(anything.require_one(members), "[]"), "ok: ()")
  assert_eq(outcome(anything.allow_one(members), "null"), "ok: ()")
}

///|
test "require_any emits anyOf of each member required" {
  let s = anything.require_any([p_a.as_member(), p_b.as_member()])
  assert_eq(s.to_json_schema(), {
    "type": "object",
    "anyOf": [{ "required": ["a"] }, { "required": ["b"] }],
  })
}

///|
test "require_one emits oneOf of each member required" {
  let s = anything.require_one([p_a.as_member(), p_b.as_member()])
  assert_eq(s.to_json_schema(), {
    "type": "object",
    "oneOf": [{ "required": ["a"] }, { "required": ["b"] }],
  })
}

///|
test "allow_one emits oneOf of each member required or none of them" {
  let s = anything.allow_one([p_a.as_member(), p_b.as_member()])
  assert_eq(s.to_json_schema(), {
    "type": "object",
    "oneOf": [
      { "required": ["a"] },
      { "required": ["b"] },
      { "not": { "anyOf": [{ "required": ["a"] }, { "required": ["b"] }] } },
    ],
  })
}

///|
test "a second constraint moves both under allOf" {
  let s = anything
    .allow_one([p_a.as_member(), p_b.as_member()])
    .require_any([p_b.as_member(), p_c.as_member()])
  assert_eq(s.to_json_schema(), {
    "type": "object",
    "allOf": [
      {
        "oneOf": [
          { "required": ["a"] },
          { "required": ["b"] },
          { "not": { "anyOf": [{ "required": ["a"] }, { "required": ["b"] }] } },
        ],
      },
      { "anyOf": [{ "required": ["b"] }, { "required": ["c"] }] },
    ],
  })
}

///|
test "a third constraint is appended to the allOf of the first two" {
  let s = anything
    .require_one([p_a.as_member()])
    .require_one([p_b.as_member()])
    .require_any([p_c.as_member()])
  assert_eq(s.to_json_schema(), {
    "type": "object",
    "allOf": [
      { "oneOf": [{ "required": ["a"] }] },
      { "oneOf": [{ "required": ["b"] }] },
      { "anyOf": [{ "required": ["c"] }] },
    ],
  })
}

///|
test "an anyOf the wrapped schema already has is kept under allOf" {
  let s = union([anything]).require_one([p_a.as_member()])
  assert_eq(s.to_json_schema(), {
    "allOf": [
      { "anyOf": [{ "type": "object" }] },
      { "oneOf": [{ "required": ["a"] }] },
    ],
  })
}

///|
test "every constraint is checked, the one added last first" {
  let s = anything
    .require_one([p_a.as_member(), p_b.as_member()])
    .allow_one([p_b.as_member(), p_c.as_member()])
  assert_eq(outcome_at(s, "{\"a\":1}"), "ok")
  assert_eq(
    outcome_at(s, "{\"c\":2}"),
    "error: act: one of `a` and `b` is required",
  )
  assert_eq(
    outcome_at(s, "{\"a\":1,\"b\":1,\"c\":2}"),
    "error: act: `b` and `c` cannot be given together",
  )
}

///|
test "a non-object JSON Schema is left unchanged" {
  let accept_all : Schema[Unit] = { json: () => true, decode: (_, _) => (), }
  let s = accept_all.require_any([p_a.as_member()])
  assert_eq(s.to_json_schema(), true)
}
