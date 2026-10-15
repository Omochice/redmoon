///|
/// An object of exactly one key, naming an action, whose value is parsed by
/// that action's schema. The top level stays a plain object because the
/// Anthropic Messages API rejects `anyOf`, `oneOf` and `allOf` there.
///
/// Entries sharing a key are alternatives for that action: they are emitted as
/// an `anyOf` inside its property and tried in order.
pub fn[T] keyed(entries : Array[(String, Schema[T])]) -> Schema[T] {
  let actions : Array[String] = []
  let shapes : Map[String, Array[Schema[T]]] = Map([])
  for entry in entries {
    match shapes.get(entry.0) {
      Some(group) => group.push(entry.1)
      None => {
        actions.push(entry.0)
        shapes[entry.0] = [entry.1]
      }
    }
  }
  let by_action : Map[String, Schema[T]] = Map([])
  for action in actions {
    let group = shapes[action]
    by_action[action] = if group.length() == 1 {
      group[0]
    } else {
      union(group)
    }
  }
  let names = actions.join(", ")
  {
    json: () => {
      let properties = json_object(actions.map(a => (a, (by_action[a].json)())))
      json_object([
        ("type", "object"),
        ("properties", properties),
        ("minProperties", Json(1)),
        ("maxProperties", Json(1)),
        ("additionalProperties", false),
      ])
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
