///|
/// An object of exactly one key, naming an action, whose value is parsed by
/// that action's schema. The top level stays a plain object because the
/// Anthropic Messages API rejects `anyOf`, `oneOf` and `allOf` there.
///
/// Aborts when an action is named twice.
pub fn[T] keyed(entries : Array[(String, Schema[T])]) -> Schema[T] {
  let actions : Array[String] = []
  let by_action : Map[String, Schema[T]] = Map([])
  for entry in entries {
    let (action, schema) = entry
    if by_action.contains(action) {
      abort("keyed: action `\{action}` is named twice")
    }
    actions.push(action)
    by_action[action] = schema
  }
  let names = actions.join(", ")
  {
    json: () => {
      let properties = Json::object(
        Map::from_array(actions.map(a => (a, (by_action[a].json)()))),
      )
      {
        "type": "object",
        "properties": properties,
        "minProperties": 1,
        "maxProperties": 1,
        "additionalProperties": false,
      }
    },
    decode: (input, path) => {
      guard input is Object(fields) &&
        fields.length() == 1 &&
        fields.iter().next() is Some((action, value)) else {
        fail(
          path,
          "expected an object with exactly one key naming the action, one of: \{names}",
        )
      }
      guard by_action.get(action) is Some(schema) else {
        fail(path, "unknown action `\{action}`, one of: \{names}")
      }
      (schema.decode)(value, [..path, action])
    },
  }
}
