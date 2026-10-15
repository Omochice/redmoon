///|
/// Accepts `null` as `None`, otherwise whatever `inner` accepts.
pub fn[T] nullable(inner : Schema[T]) -> Schema[T?] {
  {
    json: () => json_object([
      ("anyOf", Json::array([(inner.json)(), json_object([("type", "null")])])),
    ]),
    decode: (input, path) => match input {
      Null => None
      _ => Some((inner.decode)(input, path))
    },
  }
}

///|
/// Accepts what the first matching alternative accepts, emitted as `anyOf`.
/// When no alternative matches, failures inside an object are reported by
/// field; otherwise the alternatives' messages are listed.
pub fn[T] union(alternatives : Array[Schema[T]]) -> Schema[T] {
  {
    json: () => json_object([
      ("anyOf", Json::array(alternatives.map(a => (a.json)()))),
    ]),
    decode: (input, path) => {
      let failures = []
      for alternative in alternatives {
        try (alternative.decode)(input, path) catch {
          e => failures.push(e)
        } noraise {
          value => return value
        }
      }
      raise union_failure(path, failures)
    },
  }
}

///|
fn union_failure(
  path : Array[String],
  failures : Array[SchemaError],
) -> SchemaError {
  let leaves = Many(failures).leaves()
  let in_fields = leaves.filter(l => l.0.length() > path.length())
  if !in_fields.is_empty() {
    return Many(in_fields.map(l => Invalid(path=l.0, message=l.1)))
  }
  let reasons = []
  for leaf in leaves {
    if !reasons.contains(leaf.1) {
      reasons.push(leaf.1)
    }
  }
  Invalid(path~, message="no alternative matched: " + reasons.join("; "))
}
