using @schema {
  type Schema,
  type Obj,
  integer,
  number,
  string,
  not_blank,
  boolean,
  literal,
  picklist,
  choice,
  array,
  nullable,
  union,
  keyed,
  iso_date,
  object,
  field,
  optional,
  optional_or,
}

///|
fn j(text : String) -> Json {
  @json.parse(text) catch {
    _ => abort("invalid test JSON: \{text}")
  }
}

///|
fn[T : Debug] outcome(schema : Schema[T], input : String) -> String {
  try schema.parse(j(input)) catch {
    e => "error: " + e.message()
  } noraise {
    value => "ok: \{@debug.to_string(value)}"
  }
}

///|
fn[T] schema_json(schema : Schema[T]) -> String {
  schema.to_json_schema().stringify()
}
