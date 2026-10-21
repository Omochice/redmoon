///|
/// Accepts an object by the first listed alternative whose key it carries, and
/// anything else by `otherwise`.
/// Unlike `union`, a failure reports only that alternative's errors.
pub fn[T] by_key(
  alternatives : Array[(String, Schema[T])],
  otherwise? : Schema[T],
) -> Schema[T] {
  let keys = alternatives.map(a => a.0).join(", ")
  let shapes = alternatives.map(a => a.1)
  if otherwise is Some(fallback) {
    shapes.push(fallback)
  }
  {
    json: union(shapes).json,
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
