///|
/// An object schema under construction: `F` is what is left to apply, so each
/// added field fixes one parameter of the make.
pub struct Obj[F] {
  props : Array[(String, Json, Bool)]
  build : (Map[String, Json], Array[String]) -> F raise SchemaError
}

///|
/// Starts an object from a curried make taking one parameter per field.
pub fn[F] object(make : F) -> Obj[F] {
  { props: [], build: (_, _) => make, }
}

///|
/// Adds a required field, bound to the next parameter of the make.
pub fn[A, R] field(
  o : Obj[(A) -> R],
  name : String,
  schema : Schema[A],
) -> Obj[R] {
  {
    props: [..o.props, (name, (schema.json)(), true)],
    build: (fields, path) => {
      let apply = (o.build)(fields, path)
      let at = [..path, name]
      guard fields.get(name) is Some(value) else { fail(at, "is required") }
      apply((schema.decode)(value, at))
    },
  }
}

///|
/// Adds a field that may be absent, bound to an `Option` parameter.
pub fn[A, R] optional(
  o : Obj[(A?) -> R],
  name : String,
  schema : Schema[A],
) -> Obj[R] {
  {
    props: [..o.props, (name, (schema.json)(), false)],
    build: (fields, path) => {
      let apply = (o.build)(fields, path)
      match fields.get(name) {
        None => apply(None)
        Some(value) => apply(Some((schema.decode)(value, [..path, name])))
      }
    },
  }
}

///|
/// Adds a field that may be absent, bound to `default` when it is. The default
/// is advertised as the `default` keyword.
pub fn[A : ToJson, R] optional_or(
  o : Obj[(A) -> R],
  name : String,
  schema : Schema[A],
  default : A,
) -> Obj[R] {
  {
    props: [
      ..o.props,
      (
        name,
        with_keywords((schema.json)(), [("default", Json(default))]),
        false,
      ),
    ],
    build: (fields, path) => {
      let apply = (o.build)(fields, path)
      match fields.get(name) {
        None => apply(default)
        Some(value) => apply((schema.decode)(value, [..path, name]))
      }
    },
  }
}

///|
/// Finishes the object. Keys that no field names are rejected, and the schema
/// states `additionalProperties: false`.
pub fn[T] Obj::done(self : Obj[T]) -> Schema[T] {
  let known = self.props.map(p => p.0)
  {
    json: () => {
      let properties = json_object(self.props.map(p => (p.0, p.1)))
      let required = self.props.filter(p => p.2).map(p => Json(p.0))
      let entries : Array[(String, Json)] = [
        ("type", "object"),
        ("properties", properties),
      ]
      if !required.is_empty() {
        entries.push(("required", Json::array(required)))
      }
      entries.push(("additionalProperties", false))
      json_object(entries)
    },
    decode: (input, path) => {
      guard input is Object(fields) else { fail(path, "expected an object") }
      let unknown = []
      for key, _ in fields {
        if !known.contains(key) {
          unknown.push(
            SchemaError::Invalid(path=[..path, key], message="unknown field"),
          )
        }
      }
      if unknown.length() == 1 {
        raise unknown[0]
      }
      if !unknown.is_empty() {
        raise SchemaError::Many(unknown)
      }
      (self.build)(fields, path)
    },
  }
}
