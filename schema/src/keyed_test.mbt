///|
enum Input {
  List(Int32?)
  Show(Int32)
  Note(Int32, String)
  NoteDelete(Int32, Int32)
} derive(Debug)

///|
let limit : @schema.Field[Int32?] = @schema.optional("limit", integer(min=1))

///|
let list_input : Schema[Input] = @schema.record([limit.as_member()], v => {
  Input::List(v.get(limit))
})

///|
let show_id : @schema.Field[Int32] = @schema.required("id", integer(min=1))

///|
let show_input : Schema[Input] = @schema.record([show_id.as_member()], v => {
  Input::Show(v.get(show_id))
})

///|
let note_id : @schema.Field[Int32] = @schema.required("id", integer())

///|
let text : @schema.Field[String] = @schema.required("text", not_blank())

///|
let journal_id : @schema.Field[Int32] = @schema.required(
  "journal_id",
  integer(),
)

///|
let note_input : Schema[Input] = @schema.record(
  [note_id.as_member(), text.as_member()],
  v => Input::Note(v.get(note_id), v.get(text)),
)

///|
let note_by_journal : Schema[Input] = @schema.record(
  [note_id.as_member(), journal_id.as_member()],
  v => Input::NoteDelete(v.get(note_id), v.get(journal_id)),
)

///|
let tool : Schema[Input] = keyed([
  ("list", list_input),
  ("show", show_input),
  ("update_note", note_input),
  ("update_note", note_by_journal),
])

///|
test "keyed emits an action-keyed object" {
  assert_eq(
    schema_json(keyed([("list", list_input), ("show", show_input)])),
    "{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"limit\":{\"type\":\"integer\",\"minimum\":1}},\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}",
  )
}

///|
test "keyed merges duplicate keys into anyOf" {
  let json = tool.to_json_schema()
  assert_eq(
    json.stringify(),
    "{\"type\":\"object\",\"properties\":{\"list\":{\"type\":\"object\",\"properties\":{\"limit\":{\"type\":\"integer\",\"minimum\":1}},\"additionalProperties\":false},\"show\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1}},\"required\":[\"id\"],\"additionalProperties\":false},\"update_note\":{\"anyOf\":[{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\"},\"text\":{\"type\":\"string\",\"pattern\":\"\\\\S\"}},\"required\":[\"id\",\"text\"],\"additionalProperties\":false},{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\"},\"journal_id\":{\"type\":\"integer\"}},\"required\":[\"id\",\"journal_id\"],\"additionalProperties\":false}]}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}",
  )
}

///|
test "keyed parses the named action" {
  assert_eq(outcome(tool, "{\"list\":{}}"), "ok: List(None)")
  assert_eq(outcome(tool, "{\"list\":{\"limit\":5}}"), "ok: List(Some(5))")
  assert_eq(outcome(tool, "{\"show\":{\"id\":3}}"), "ok: Show(3)")
  assert_eq(
    outcome(tool, "{\"update_note\":{\"id\":1,\"text\":\"hi\"}}"),
    "ok: Note(1, \"hi\")",
  )
  assert_eq(
    outcome(tool, "{\"update_note\":{\"id\":1,\"journal_id\":2}}"),
    "ok: NoteDelete(1, 2)",
  )
}

///|
test "keyed rejects a wrong shape" {
  let expected = "error: expected an object with exactly one key naming the action, one of: list, show, update_note"
  assert_eq(outcome(tool, "{}"), expected)
  assert_eq(outcome(tool, "{\"list\":{},\"show\":{\"id\":1}}"), expected)
  assert_eq(outcome(tool, "[]"), expected)
  assert_eq(outcome(tool, "null"), expected)
}

///|
test "keyed rejects an unknown action" {
  assert_eq(
    outcome(tool, "{\"delete\":{}}"),
    "error: unknown action `delete`, one of: list, show, update_note",
  )
}

///|
test "keyed names the action and field in errors" {
  assert_eq(outcome(tool, "{\"show\":{}}"), "error: show.id: is required")
  assert_eq(
    outcome(tool, "{\"show\":{\"id\":0}}"),
    "error: show.id: must be at least 1",
  )
  assert_eq(
    outcome(tool, "{\"show\":{\"id\":1,\"projectId\":2}}"),
    "error: show.projectId: unknown field",
  )
  assert_eq(outcome(tool, "{\"show\":3}"), "error: show: expected an object")
}

///|
test "keyed reports field errors of duplicated shapes" {
  assert_eq(
    outcome(tool, "{\"update_note\":{\"id\":1}}"),
    "error: update_note.text: is required; update_note.journal_id: is required",
  )
  assert_eq(
    outcome(tool, "{\"update_note\":{\"id\":1,\"text\":\" \"}}"),
    "error: update_note.text: must not be blank; update_note.text: unknown field",
  )
}

///|
test "keyed can be nested under a caller's path" {
  let result = try tool.parse_at(j("{\"show\":{}}"), ["tool"]) catch {
    e => e.message()
  } noraise {
    _ => "ok"
  }
  assert_eq(result, "tool.show.id: is required")
}
