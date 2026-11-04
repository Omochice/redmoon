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

The definition below decodes `{"name": "...", "limit": 10}` into a struct and advertises the matching schema.

```moonbit
struct Query {
  name : String
  limit : Int32
}

let name = @schema.required("name", @schema.not_blank())
let limit = @schema.optional_or("limit", @schema.integer(min=1), 25)

let query : @schema.Schema[Query] = @schema.record(
  [name.as_member(), limit.as_member()],
  v => { name: v.get(name), limit: v.get(limit) },
)

fn example(input : Json) -> Query raise @schema.SchemaError {
  query.parse(input)
}
```

`query.to_json_schema()` returns the object schema with `name` required, `limit` defaulted to `25`, and `additionalProperties: false`.
