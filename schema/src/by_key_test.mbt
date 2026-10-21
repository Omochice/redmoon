///|
enum Lookup {
  ById(Int32)
  ByName(String)
  Everything
} derive(Debug)

///|
let lookup_id : @schema.Field[Int32] = @schema.required("id", integer(min=1))

///|
let by_id : Schema[Lookup] = @schema.record([lookup_id.as_member()], v => {
  Lookup::ById(v.get(lookup_id))
})

///|
let lookup_name : @schema.Field[String] = @schema.required("name", not_blank())

///|
let by_name : Schema[Lookup] = @schema.record([lookup_name.as_member()], v => {
  Lookup::ByName(v.get(lookup_name))
})

///|
let everything : Schema[Lookup] = @schema.record([], _ => Lookup::Everything)

///|
let lookup : Schema[Lookup] = by_key([("id", by_id), ("name", by_name)])

///|
let lookup_or_everything : Schema[Lookup] = by_key(
  [("id", by_id), ("name", by_name)],
  otherwise=everything,
)

///|
test "by_key decodes with the alternative whose key is present" {
  assert_eq(outcome(lookup, "{\"id\":3}"), "ok: ById(3)")
  assert_eq(outcome(lookup, "{\"name\":\"n\"}"), "ok: ByName(\"n\")")
}

///|
test "by_key reports only the failures of the alternative its key picks" {
  assert_eq(outcome(lookup, "{\"id\":0}"), "error: id: must be at least 1")
  assert_eq(
    outcome(lookup, "{\"name\":\" \"}"),
    "error: name: must not be blank",
  )
}

///|
test "by_key picks the alternative listed first when several keys are present" {
  assert_eq(
    outcome(lookup, "{\"id\":3,\"name\":\"n\"}"),
    "error: name: unknown field",
  )
  assert_eq(
    outcome(
      by_key([("name", by_name), ("id", by_id)]),
      "{\"id\":3,\"name\":\"n\"}",
    ),
    "error: id: unknown field",
  )
}

///|
test "by_key decodes an object without any of the keys with otherwise" {
  assert_eq(outcome(lookup_or_everything, "{}"), "ok: Everything")
  assert_eq(
    outcome(lookup_or_everything, "{\"other\":1}"),
    "error: other: unknown field",
  )
}

///|
test "by_key without otherwise names the keys when none is present" {
  assert_eq(outcome(lookup, "{}"), "error: expected one of the keys id, name")
  let result = try lookup.parse_at(j("{}"), ["act"]) catch {
    e => e.message()
  } noraise {
    _ => "ok"
  }
  assert_eq(result, "act: expected one of the keys id, name")
}

///|
test "by_key decodes a non-object with otherwise, and rejects it without" {
  let s = by_key([("id", by_id)], otherwise=integer().map(n => Lookup::ById(n)))
  assert_eq(outcome(s, "7"), "ok: ById(7)")
  assert_eq(outcome(lookup, "3"), "error: expected an object")
  assert_eq(outcome(lookup, "[]"), "error: expected an object")
}

///|
test "by_key emits anyOf of the alternatives in order, then otherwise" {
  assert_eq(
    schema_json(lookup_or_everything),
    "{\"anyOf\":[{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false},{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"pattern\":\"\\\\S\"}},\"required\":[\"name\"],\"additionalProperties\":false},{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}]}",
  )
  assert_eq(
    schema_json(by_key([("name", by_name)])),
    "{\"anyOf\":[{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"pattern\":\"\\\\S\"}},\"required\":[\"name\"],\"additionalProperties\":false}]}",
  )
}
