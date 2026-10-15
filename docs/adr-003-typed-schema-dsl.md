# ADR-003: A Typed Schema DSL as Its Own Module

## Status

Proposed (refined by [ADR-011](./adr-011-design-evolution-from-adr-003.md))

## Context

Every MCP tool advertises its arguments as a JSON Schema (`inputSchema`) and receives them as JSON in `tools/call`.
denomine-mcp defines each argument shape once in valibot, derives the advertised schema with `toJsonSchema`, and validates calls with `safeParse` against the same definition, so the advertised schema and the validation cannot drift (its ADR-0001).

redmoon decodes the arguments into typed MoonBit values, because the Redmine SDK takes typed input ([ADR-006](./adr-006-typed-redmine-sdk.md)).
MoonBit has `derive(FromJson)`, which decodes a struct but produces no JSON Schema, and it has no macros or reflection from which a schema could be generated.

The schema also has to express the action-keyed tool shape of [ADR-005](./adr-005-tool-surface.md), which uses `minProperties`, `maxProperties`, and `additionalProperties: false`.

## Decision Drivers

- **No drift**: the advertised schema and the validation come from one definition.
- **Typed output**: validation yields the MoonBit value a handler uses, not a JSON value to decode again.
- **Readable errors**: a failure names the offending field by path, so the model can correct it.

## Considered Options

### Option 1: `derive(FromJson)` plus a hand-written JSON Schema

**Pros:**

- Least code to write.

**Cons:**

- Two definitions per tool, which drift apart as fields are added.

### Option 2: `mizchi/jsonschema`

A JSON Schema validator with a zod-like builder.

**Pros:**

- Already published.

**Cons:**

- Its README lists `minProperties` and `maxProperties` as unsupported.
- Its validator answers on a JSON value, so a typed value still needs `derive(FromJson)`, which brings back the two definitions of option 1.

### Option 3: A combinator DSL in this repository (chosen)

A `Schema[T]` carries both a JSON Schema and a parser to `T`, and object schemas are built field by field into a constructor.

**Pros:**

- One definition, typed output, and exactly the keywords the tools need.

**Cons:**

- A library to write and maintain.

For placement, the DSL could live inside `omochice/mcp`, inside `omochice/redmoon`, or in a module of its own.
Inside `mcp` saves a module, but every user of the validator then depends on the MCP server and every MCP release bumps it.
Inside `redmoon` is smallest, but an MCP SDK published without it leaves its users to write schemas by hand, and moving it later renames every import.

## Decision

We will write `omochice/schema` as a module of its own, and `omochice/mcp` will take a `Schema[T]` for each tool's arguments.

### 1. A schema is a pair of a JSON Schema and a typed parser

```moonbit
struct Schema[T] {
  json : () -> Json
  parse : (Json, Array[String]) -> T raise SchemaError
}
```

**Rationale**: holding both in one value is what makes drift impossible; any combinator that builds the parser builds the schema in the same step.

### 2. Objects are built by adding fields to a curried constructor

```moonbit
let version_create : Schema[VersionCreate] = object(project_id => name => status => {
  project_id,
  name,
  status,
})
  |> field("project_id", int_(min=1))
  |> field("name", string_())
  |> optional("status", picklist(["open", "locked", "closed"]))
  |> Obj::done
```

`field` takes an `Obj[(A) -> R]` and returns an `Obj[R]`, so each added field fixes one parameter and a missing or mistyped field is a compile error.
`done` rejects unknown keys and emits `additionalProperties: false`.

**Rationale**: MoonBit cannot derive a schema from a struct, so the struct has to be assembled from parsed fields; a curried constructor lets the type checker follow the assembly without one helper per field count.
A prototype of exactly this code compiled with moonc v0.10.15 and produced the expected schema and errors:

```text
{"type":"object","properties":{"project_id":{"type":"integer","minimum":1},"name":{"type":"string"},"status":{"type":"string","enum":["open","locked","closed"]}},"required":["project_id","name"],"additionalProperties":false}
error: create.status: must be one of open, locked, closed
error: create.project_id: is required
error: create.extra: unknown field
```

### 3. Errors carry a path

`SchemaError` holds the path from the root and a message, and its text is `<path joined by .>: <message>`.

**Rationale**: denomine-mcp answers `<action>.<field>: <message>`, which lets a model fix one field and retry; keeping the path structured lets the caller prefix the action name.

## Consequences

### Positive

1. **No drift**: the advertised schema and the validation share one definition.
2. **Typed handlers**: a handler receives a struct and needs no casts.
3. **Reusable**: the validator can check any JSON input, not only MCP arguments.

### Negative

1. **Position, not name, joins a field to its parameter**: swapping two fields of the same type, such as two `String` fields, compiles and silently exchanges their values.
2. **A sixth piece of code to maintain**, written from scratch.
3. **Only the keywords redmoon uses** are supported at first.

### Mitigations

- Each tool schema has a test that parses a complete input and checks every field of the result, which catches a swapped pair.
- The keyword set grows only when a tool needs it, so nothing is maintained without a user.

## References

- [ADR-001](./adr-001-five-module-moonbit-workspace.md) — the module layout.
- [ADR-005](./adr-005-tool-surface.md) — the schema shape the tools advertise.
- [mizchi/jsonschema](https://github.com/mizchi/moonbit-jsonschema) — the existing library considered.
