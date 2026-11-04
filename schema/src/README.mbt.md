# omochice/schema

A typed schema DSL in which one definition yields both a JSON Schema and a decoder to a MoonBit value, so the schema a program advertises and the validation it performs cannot drift apart.

## What is supported

The combinators below are the whole public surface of the module.

- Scalars: `string`, `not_blank`, `literal`, `choice`, `iso_date`, `integer` (`Int32`), `integer64` (`Int64`), `number`, and `boolean`.
- Containers: `array`, `nullable`, and `record`, whose members are `required`, `optional`, and `optional_or` handles read back through `Values::get`.
- Variants: `union` for alternatives, and `keyed` and `by_key` for objects whose shape depends on a key they carry.
- Refinements on any schema: `describe`, `map`, `refine`, `allow_one`, `require_one`, and `require_any`.
- `Schema::to_json_schema` emits JSON Schema draft 2020-12, and `Schema::parse` decodes a value, raising `SchemaError` with the path of the offending member.

## What is not supported

The limits below follow from the design, which builds a schema by hand rather than from a type.

- No derivation from a struct; every object is a `record` of listed members.
- No JSON Schema keywords beyond those the combinators emit, other than what `refine` adds through `keywords`.
- No validation of a JSON Schema itself; the module only produces one.

## Usage

The definition below decodes an object into a pair, filling in the default of a member that is absent, and advertises the matching schema.
The block is a test, so `moon test` keeps it true.

```mbt check
///|
test "one definition decodes a value and advertises its schema" {
  let name = @schema.required("name", @schema.not_blank())
  let limit = @schema.optional_or("limit", @schema.integer(min=1), 25)
  let query : @schema.Schema[(String, Int32)] = @schema.record(
    [name.as_member(), limit.as_member()],
    v => (v.get(name), v.get(limit)),
  )
  assert_eq(query.parse({ "name": "redmoon" }), ("redmoon", 25))
  inspect(
    query.to_json_schema().stringify(),
    content=(
      #|{"type":"object","properties":{"name":{"type":"string","pattern":"\\S"},"limit":{"type":"integer","minimum":1,"default":25}},"required":["name"],"additionalProperties":false}
    ),
  )
}
```

A value that fails the schema raises `SchemaError`, whose message names the member.
