///|
/// A JSON Schema paired with the parser that produces a `T` from a value
/// satisfying it, so the advertised schema and the validation cannot drift.
pub(all) struct Schema[T] {
  json : () -> Json
  decode : (Json, Array[String]) -> T raise SchemaError
}

///|
/// The JSON Schema (draft 2020-12) of the values the schema accepts.
pub fn[T] Schema::to_json_schema(self : Schema[T]) -> Json {
  (self.json)()
}

///|
/// Parses `input`, raising `SchemaError` with the path of the offending value.
pub fn[T] Schema::parse(self : Schema[T], input : Json) -> T raise SchemaError {
  (self.decode)(input, [])
}

///|
/// Like `parse`, with `path` prepended to every reported path, so a caller can
/// name the action the value belongs to.
pub fn[T] Schema::parse_at(
  self : Schema[T],
  input : Json,
  path : Array[String],
) -> T raise SchemaError {
  (self.decode)(input, path)
}

///|
/// Adds a `description` to the emitted schema.
pub fn[T] Schema::describe(self : Schema[T], text : String) -> Schema[T] {
  { json: () => with_keywords((self.json)(), [("description", Json(text))]), decode: self.decode }
}

///|
/// Converts the parsed value; the emitted schema is unchanged.
pub fn[A, B] Schema::map(self : Schema[A], f : (A) -> B) -> Schema[B] {
  { json: self.json, decode: (input, path) => f((self.decode)(input, path)) }
}

///|
/// Rejects values for which `check` is false with `message`. `keywords` are
/// merged into the emitted schema so the advertised schema states the same
/// constraint, e.g. a `pattern` that MoonBit cannot evaluate itself.
pub fn[T] Schema::refine(
  self : Schema[T],
  check : (T) -> Bool,
  message : String,
  keywords? : Array[(String, Json)] = [],
) -> Schema[T] {
  {
    json: () => with_keywords((self.json)(), keywords),
    decode: (input, path) => {
      let value = (self.decode)(input, path)
      if !check(value) {
        fail(path, message)
      }
      value
    },
  }
}

///|
/// An integer, optionally bounded (inclusive).
pub fn integer(min? : Int, max? : Int) -> Schema[Int] {
  {
    json: () => {
      let entries : Array[(String, Json)] = [("type", "integer")]
      if min is Some(m) {
        entries.push(("minimum", Json(m)))
      }
      if max is Some(m) {
        entries.push(("maximum", Json(m)))
      }
      json_object(entries)
    },
    decode: (input, path) => {
      guard input is Number(d, ..) && d == d.floor() && d >= -2147483648.0 && d <= 2147483647.0 else {
        fail(path, "expected an integer")
      }
      let n = d.to_int()
      if min is Some(m) && n < m {
        fail(path, "must be at least \{m}")
      }
      if max is Some(m) && n > m {
        fail(path, "must be at most \{m}")
      }
      n
    },
  }
}

///|
/// A number, optionally bounded (inclusive).
pub fn number(min? : Double, max? : Double) -> Schema[Double] {
  {
    json: () => {
      let entries : Array[(String, Json)] = [("type", "number")]
      if min is Some(m) {
        entries.push(("minimum", Json(m)))
      }
      if max is Some(m) {
        entries.push(("maximum", Json(m)))
      }
      json_object(entries)
    },
    decode: (input, path) => {
      guard input is Number(d, ..) else { fail(path, "expected a number") }
      if min is Some(m) && d < m {
        fail(path, "must be at least \{m}")
      }
      if max is Some(m) && d > m {
        fail(path, "must be at most \{m}")
      }
      d
    },
  }
}

///|
/// A string, optionally bounded in length (in characters).
pub fn string(min_length? : Int, max_length? : Int) -> Schema[String] {
  {
    json: () => {
      let entries : Array[(String, Json)] = [("type", "string")]
      if min_length is Some(m) {
        entries.push(("minLength", Json(m)))
      }
      if max_length is Some(m) {
        entries.push(("maxLength", Json(m)))
      }
      json_object(entries)
    },
    decode: (input, path) => {
      guard input is String(s) else { fail(path, "expected a string") }
      let length = s.iter().count()
      if min_length is Some(m) && length < m {
        fail(path, "must be at least \{m} characters")
      }
      if max_length is Some(m) && length > m {
        fail(path, "must be at most \{m} characters")
      }
      s
    },
  }
}

///|
/// A string containing at least one non-whitespace character.
pub fn not_blank() -> Schema[String] {
  string().refine(
    s => s.iter().any(c => !c.is_whitespace()),
    "must not be blank",
    keywords=[("pattern", "\\S")],
  )
}

///|
/// A boolean.
pub fn boolean() -> Schema[Bool] {
  {
    json: () => json_object([("type", "boolean")]),
    decode: (input, path) => match input {
      True => true
      False => false
      _ => fail(path, "expected a boolean")
    },
  }
}

///|
/// Exactly the string `value`.
pub fn literal(value : String) -> Schema[String] {
  {
    json: () => json_object([("type", "string"), ("const", Json(value))]),
    decode: (input, path) => {
      guard input is String(s) && s == value else {
        fail(path, "must be `\{value}`")
      }
      s
    },
  }
}

///|
/// One of the listed strings.
pub fn picklist(values : Array[String]) -> Schema[String] {
  choice(values.map(v => (v, v)))
}

///|
/// One of the listed names, parsed to the value paired with it.
pub fn[T] choice(options : Array[(String, T)]) -> Schema[T] {
  let names = options.map(o => o.0)
  {
    json: () => json_object([
      ("type", "string"),
      ("enum", Json::array(names.map(n => Json(n)))),
    ]),
    decode: (input, path) => {
      guard input is String(s) else {
        fail(path, "must be one of \{names.join(", ")}")
      }
      for option in options {
        if option.0 == s {
          return option.1
        }
      }
      fail(path, "must be one of \{names.join(", ")}")
    },
  }
}

///|
/// An array whose items all satisfy `item`.
pub fn[T] array(item : Schema[T], min_items? : Int) -> Schema[Array[T]] {
  {
    json: () => {
      let entries : Array[(String, Json)] = [
        ("type", "array"),
        ("items", (item.json)()),
      ]
      if min_items is Some(m) {
        entries.push(("minItems", Json(m)))
      }
      json_object(entries)
    },
    decode: (input, path) => {
      guard input is Array(items) else { fail(path, "expected an array") }
      if min_items is Some(m) && items.length() < m {
        fail(path, "must have at least \{m} items")
      }
      items.mapi((i, v) => (item.decode)(v, [..path, i.to_string()]))
    },
  }
}
