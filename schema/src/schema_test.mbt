///|
test "integer emits bounds" {
  assert_eq(schema_json(integer()), "{\"type\":\"integer\"}")
  assert_eq(
    schema_json(integer(min=1, max=9)),
    "{\"type\":\"integer\",\"minimum\":1,\"maximum\":9}",
  )
}

///|
test "integer parses and bounds" {
  let s = integer(min=1, max=9)
  assert_eq(outcome(s, "5"), "ok: 5")
  assert_eq(outcome(s, "1"), "ok: 1")
  assert_eq(outcome(s, "0"), "error: must be at least 1")
  assert_eq(outcome(s, "10"), "error: must be at most 9")
  assert_eq(outcome(s, "1.5"), "error: expected an integer")
  assert_eq(outcome(s, "\"1\""), "error: expected an integer")
  assert_eq(outcome(integer(), "5000000000"), "error: expected an integer")
}

///|
test "integer64 emits bounds as numbers" {
  assert_eq(schema_json(integer64()), "{\"type\":\"integer\"}")
  assert_eq(
    schema_json(integer64(min=1, max=5000000000)),
    "{\"type\":\"integer\",\"minimum\":1,\"maximum\":5000000000}",
  )
}

///|
test "integer64 parses integers beyond Int32 and bounds" {
  let s = integer64(min=1, max=5000000000)
  assert_eq(outcome(s, "3000000000"), "ok: 3000000000")
  assert_eq(outcome(s, "5000000000"), "ok: 5000000000")
  assert_eq(outcome(s, "0"), "error: must be at least 1")
  assert_eq(outcome(s, "5000000001"), "error: must be at most 5000000000")
  assert_eq(outcome(s, "1.5"), "error: expected an integer")
  assert_eq(outcome(s, "\"3000000000\""), "error: expected an integer")
  assert_eq(outcome(integer64(), "1e19"), "error: expected an integer")
}

///|
test "number emits and parses" {
  assert_eq(
    schema_json(number(min=0.5)),
    "{\"type\":\"number\",\"minimum\":0.5}",
  )
  assert_eq(outcome(number(), "1.25"), "ok: 1.25")
  assert_eq(outcome(number(min=1.0), "0.5"), "error: must be at least 1")
  assert_eq(outcome(number(), "null"), "error: expected a number")
}

///|
test "string emits and parses" {
  assert_eq(schema_json(string()), "{\"type\":\"string\"}")
  assert_eq(
    schema_json(string(min_length=1, max_length=3)),
    "{\"type\":\"string\",\"minLength\":1,\"maxLength\":3}",
  )
  let s = string(min_length=2, max_length=3)
  assert_eq(outcome(s, "\"ab\""), "ok: \"ab\"")
  assert_eq(outcome(s, "\"a\""), "error: must be at least 2 characters")
  assert_eq(outcome(s, "\"abcd\""), "error: must be at most 3 characters")
  assert_eq(outcome(s, "3"), "error: expected a string")
}

///|
test "not_blank carries a real pattern" {
  assert_eq(
    schema_json(not_blank()),
    "{\"type\":\"string\",\"pattern\":\"\\\\S\"}",
  )
  assert_eq(outcome(not_blank(), "\" x \""), "ok: \" x \"")
  assert_eq(outcome(not_blank(), "\"  \""), "error: must not be blank")
  assert_eq(outcome(not_blank(), "\"\""), "error: must not be blank")
}

///|
test "not_blank bounds the length like string" {
  let s = not_blank(max_length=3)
  assert_eq(
    schema_json(s),
    "{\"type\":\"string\",\"maxLength\":3,\"pattern\":\"\\\\S\"}",
  )
  assert_eq(outcome(s, "\"abc\""), "ok: \"abc\"")
  assert_eq(outcome(s, "\"abcd\""), "error: must be at most 3 characters")
  assert_eq(outcome(s, "\"   \""), "error: must not be blank")
}

///|
test "boolean" {
  assert_eq(schema_json(boolean()), "{\"type\":\"boolean\"}")
  assert_eq(outcome(boolean(), "true"), "ok: true")
  assert_eq(outcome(boolean(), "false"), "ok: false")
  assert_eq(outcome(boolean(), "0"), "error: expected a boolean")
}

///|
test "literal" {
  let s = literal("show")
  assert_eq(schema_json(s), "{\"type\":\"string\",\"const\":\"show\"}")
  assert_eq(outcome(s, "\"show\""), "ok: \"show\"")
  assert_eq(outcome(s, "\"list\""), "error: must be `show`")
}

///|
test "choice maps names to values" {
  let s = choice([("asc", 1), ("desc", -1)])
  assert_eq(outcome(s, "\"desc\""), "ok: -1")
  assert_eq(outcome(s, "\"up\""), "error: must be one of `asc` and `desc`")
  assert_eq(outcome(s, "1"), "error: expected a string")
  assert_eq(schema_json(s), "{\"type\":\"string\",\"enum\":[\"asc\",\"desc\"]}")
}

///|
test "array" {
  let s = array(integer(min=1), min_items=1)
  assert_eq(
    schema_json(s),
    "{\"type\":\"array\",\"items\":{\"type\":\"integer\",\"minimum\":1},\"minItems\":1}",
  )
  assert_eq(outcome(s, "[1,2]"), "ok: [1, 2]")
  assert_eq(outcome(s, "[]"), "error: must have at least 1 items")
  assert_eq(outcome(s, "[1,0]"), "error: 1: must be at least 1")
  assert_eq(outcome(s, "{}"), "error: expected an array")
  assert_eq(
    outcome(array(choice([("a", "a")])), "[\"a\",\"b\"]"),
    "error: 1: must be one of `a`",
  )
}

///|
test "describe adds a description" {
  assert_eq(
    schema_json(string().describe("A name")),
    "{\"type\":\"string\",\"description\":\"A name\"}",
  )
}

///|
test "map converts the parsed value only" {
  let s = integer().map(n => n * 2)
  assert_eq(outcome(s, "4"), "ok: 8")
  assert_eq(schema_json(s), "{\"type\":\"integer\"}")
}

///|
test "refine rejects and adds keywords" {
  let s = string().refine(v => v.has_prefix("#"), "must start with #", keywords=[
    ("pattern", "^#"),
  ])
  assert_eq(schema_json(s), "{\"type\":\"string\",\"pattern\":\"^#\"}")
  assert_eq(outcome(s, "\"#a\""), "ok: \"#a\"")
  assert_eq(outcome(s, "\"a\""), "error: must start with #")
}

///|
test "a refine stacked on another keeps both keywords under allOf" {
  let s = not_blank().refine(
    v => !v.contains_char(','),
    "must not contain a comma",
    keywords=[("pattern", "^[^,]*$")],
  )
  assert_eq(
    schema_json(s),
    "{\"type\":\"string\",\"allOf\":[{\"pattern\":\"\\\\S\"},{\"pattern\":\"^[^,]*$\"}]}",
  )
  assert_eq(outcome(s, "\"a\""), "ok: \"a\"")
  assert_eq(outcome(s, "\" \""), "error: must not be blank")
  assert_eq(outcome(s, "\"a,b\""), "error: must not contain a comma")
}

///|
test "describe twice keeps the last description" {
  assert_eq(
    schema_json(string().describe("A name").describe("The name")),
    "{\"type\":\"string\",\"description\":\"The name\"}",
  )
}
