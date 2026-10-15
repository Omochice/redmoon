///|
/// A named member of an object whose parsed value is a `T`. It is declared once
/// and then both listed in `record` and read from `Values`, so a value is
/// always fetched by the name that produced it.
struct Field[T] {
  name : String
  json : () -> Json
  required : Bool
  read : (Json?, Array[String]) -> T raise SchemaError
}

///|
/// A `Field` with its value type erased so members of different types fit in
/// one list.
struct Member {
  name : String
  json : () -> Json
  required : Bool
  check : (Map[String, Json], Array[String]) -> Unit raise SchemaError
}

///|
/// The members of an object being parsed, read by `Field` handle.
struct Values {
  fields : Map[String, Json]
  names : Array[String]
  path : Array[String]
}

///|
/// A member that must be present.
pub fn[T] required(name : String, schema : Schema[T]) -> Field[T] {
  {
    name,
    json: schema.json,
    required: true,
    read: (value, path) => {
      let at = [..path, name]
      guard value is Some(value) else { fail(at, "is required") }
      (schema.decode)(value, at)
    },
  }
}

///|
/// A member that may be absent, in which case its value is `None`.
pub fn[T] optional(name : String, schema : Schema[T]) -> Field[T?] {
  {
    name,
    json: schema.json,
    required: false,
    read: (value, path) => {
      match value {
        None => None
        Some(value) => Some((schema.decode)(value, [..path, name]))
      }
    },
  }
}

///|
/// A member that may be absent, in which case its value is `default`. The
/// default is advertised as the `default` keyword.
pub fn[T : ToJson] optional_or(
  name : String,
  schema : Schema[T],
  default : T,
) -> Field[T] {
  {
    name,
    json: () => with_keywords((schema.json)(), [("default", Json(default))]),
    required: false,
    read: (value, path) => {
      match value {
        None => default
        Some(value) => (schema.decode)(value, [..path, name])
      }
    },
  }
}

///|
/// Erases the value type so the field can be listed in `record`.
pub fn[T] Field::as_member(self : Field[T]) -> Member {
  {
    name: self.name,
    json: self.json,
    required: self.required,
    check: (fields, path) => ignore((self.read)(fields.get(self.name), path)),
  }
}

///|
/// The value of `field`, which must have been listed in `record`; raises
/// `SchemaError` otherwise, because the schema never validated it.
pub fn[T] Values::get(self : Values, field : Field[T]) -> T raise SchemaError {
  guard self.names.contains(field.name) else {
    fail(self.path, "\{field.name} is not a member of the record")
  }
  (field.read)(self.fields.get(field.name), self.path)
}

///|
/// An object of exactly the listed members. Keys that no member names are
/// rejected, every member is validated before `build` runs, and the failures
/// of all of them are reported together.
pub fn[T] record(
  members : Array[Member],
  build : (Values) -> T raise SchemaError,
) -> Schema[T] {
  let names = members.map(m => m.name)
  {
    json: () => {
      let properties = json_object(members.map(m => (m.name, (m.json)())))
      let required = members.filter(m => m.required).map(m => Json(m.name))
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
      let errors = []
      for key, _ in fields {
        if !names.contains(key) {
          errors.push(
            SchemaError::Invalid(path=[..path, key], message="unknown field"),
          )
        }
      }
      if !errors.is_empty() {
        raise if errors.length() == 1 { errors[0] } else { Many(errors) }
      }
      for m in members {
        try (m.check)(fields, path) catch {
          e => errors.push(e)
        } noraise {
          _ => ()
        }
      }
      if errors.length() == 1 {
        raise errors[0]
      }
      if !errors.is_empty() {
        raise SchemaError::Many(errors)
      }
      build({ fields, names, path, })
    },
  }
}
