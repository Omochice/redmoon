///|
let plain_object : @schema.Schema[Unit] = {
  json: () => { "type": "object" },
  decode: (_, _) => (),
}

///|
test "exclusive_text states an optional pair as at most one of the two" {
  let schema = exclusive_text(plain_object, field="notes")
  assert_eq(schema.to_json_schema(), {
    "type": "object",
    "oneOf": [
      { "required": ["notes"] },
      { "required": ["notes_path"] },
      {
        "not": {
          "anyOf": [{ "required": ["notes"] }, { "required": ["notes_path"] }],
        },
      },
    ],
  })
}

///|
test "exclusive_text states a required pair as exactly one of the two" {
  let schema = exclusive_text(plain_object, field="text", required=true)
  assert_eq(schema.to_json_schema(), {
    "type": "object",
    "oneOf": [{ "required": ["text"] }, { "required": ["text_path"] }],
  })
}

///|
test "exclusive_text keeps both pairs of a nested use under allOf" {
  let schema = exclusive_text(
    exclusive_text(plain_object, field="description", required=true),
    field="notes",
    required=true,
  )
  assert_eq(schema.to_json_schema(), {
    "type": "object",
    "allOf": [
      {
        "oneOf": [
          { "required": ["description"] },
          { "required": ["description_path"] },
        ],
      },
      { "oneOf": [{ "required": ["notes"] }, { "required": ["notes_path"] }] },
    ],
  })
}

///|
test "exclusive_text appends a third pair to the allOf of the first two" {
  let schema = exclusive_text(
    exclusive_text(
      exclusive_text(plain_object, field="a", required=true),
      field="b",
      required=true,
    ),
    field="c",
    required=true,
  )
  assert_eq(schema.to_json_schema(), {
    "type": "object",
    "allOf": [
      { "oneOf": [{ "required": ["a"] }, { "required": ["a_path"] }] },
      { "oneOf": [{ "required": ["b"] }, { "required": ["b_path"] }] },
      { "oneOf": [{ "required": ["c"] }, { "required": ["c_path"] }] },
    ],
  })
}
