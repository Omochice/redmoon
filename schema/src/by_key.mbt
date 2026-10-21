///|
/// Accepts an object decoded by the alternative whose key it carries, the
/// first listed one when it carries several, emitted as `anyOf`.
/// Anything else is decoded by `otherwise`, which comes last in the `anyOf`.
/// Unlike `union`, a failure reports only the selected alternative's errors.
pub fn[T] by_key(
  alternatives : Array[(String, Schema[T])],
  otherwise? : Schema[T],
) -> Schema[T] {
  let keys = alternatives.map(a => a.0).join(", ")
  {
    json: () => {
      let shapes = alternatives.map(a => (a.1.json)())
      if otherwise is Some(fallback) {
        shapes.push((fallback.json)())
      }
      { "anyOf": Json::array(shapes) }
    },
    decode: (input, path) => {
      if input is Object(fields) {
        for alternative in alternatives {
          if fields.contains(alternative.0) {
            return (alternative.1.decode)(input, path)
          }
        }
      }
      match (otherwise, input) {
        (Some(fallback), _) => (fallback.decode)(input, path)
        (None, Object(_)) => fail(path, "expected one of the keys \{keys}")
        (None, _) => fail(path, "expected an object")
      }
    },
  }
}
