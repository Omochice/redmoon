# ADR-011: Design Evolution from ADR-003

## Status

Proposed

## Context

[ADR-003](./adr-003-typed-schema-dsl.md) decided that `omochice/schema` provides one definition per argument shape that yields both a JSON Schema and a typed parser.
Its decision 2 built object schemas by adding fields to a curried constructor:

```moonbit
@schema.object(project_id => name => status => { project_id, name, status })
|> @schema.field("project_id", int_(min=1))
|> @schema.field("name", string_())
|> @schema.optional("status", picklist(["open", "locked", "closed"]))
|> @schema.Obj::done
```

Implementing the `redmine_issues` tool put this to the test with objects of 12, 13, and 17 fields.
`moonfmt` from moonc v0.10.15 takes time that grows exponentially with the length of a curried arrow chain.
A synthetic `f(a1 => a2 => ... => {...})` measured 0.02 s for 8 parameters, 0.08 s for 10, and 0.62 s for 12; the definitions cut out of the issues tool measured 0.79 s for 12 fields, 1.89 s for 13, and 390 s for 17, and the whole file did not finish within 180 s.
`nix fmt` runs that formatter in the pre-push hook and in the CI `formatting` check, so the curried form makes both hang.

ADR-003 also recorded, as its first negative consequence, that the curried form joins a field to its parameter by position, so two fields of the same type can be swapped without a compile error.

This ADR records how decision 2 changed; decisions 1 and 3 of ADR-003 still hold.

## Design Changes from ADR-003

### 1. Object members are named typed handles read by a builder

**Original Design (ADR-003)**: an `Obj[F]` holds a curried constructor, `field` and `optional` each fix one parameter, and `Obj::done` produces the strict object schema.

**Revised Design**: each member is declared once as a `Field[T]`, and an object is a list of members plus a function that reads the members by handle.

```moonbit
let project_id : Field[Int] = @schema.required("project_id", record_id())
let name : Field[String] = @schema.required("name", @schema.string())
let status : Field[String?] = @schema.optional("status", version_status())

let version_create : Schema[VersionCreate] = @schema.record(
  [project_id.member(), name.member(), status.member()],
  values => {
    project_id: values.get(project_id),
    name: values.get(name),
    status: values.get(status),
  },
)
```

`required` gives `Field[T]`, `optional` gives `Field[T?]` that is `None` when the member is absent, and `optional_or` gives `Field[T]` with a default it also advertises.
`record` emits `properties`, `required`, and `additionalProperties: false` from the member list, rejects unknown keys, validates every member and collects all their errors before calling the builder, and then lets the builder read each value with `Values::get`, which raises `SchemaError` only for a handle that was not listed.

**Rationale**: the builder is a flat sequence of reads, so formatting cost no longer depends on the number of fields; a 20-field record formats in 0.008 s.
Each value is read through the handle that names it, so the compiler ties `values.get(project_id)` to `Int` and a read of the wrong member is visible in the source, which removes ADR-003's position-based swap.
A prototype of exactly this API compiled with moonc v0.10.15 and produced the same JSON Schema and error messages as the curried form:

```text
{"type":"object","properties":{"project_id":{"type":"integer","minimum":1},"name":{"type":"string"},"description":{"type":"string"}},"required":["project_id","name"],"additionalProperties":false}
error: create.project_id: expected integer >= 1
error: create.project_id: is required
error: create.extra: unknown field
```

### 2. The curried builder is removed

**Original Design (ADR-003)**: `object`, `field`, `optional`, `optional_or`, and `Obj::done` are the only way to build an object schema.

**Revised Design**: those functions are removed once every tool has moved to `record`.

**Rationale**: keeping both would give the module two ways to build the same thing, and the curried one would remain a trap for any object with more than about a dozen fields.

## Consequences

### Positive

1. **Formatting stays fast** regardless of how many fields an object has, so `nix fmt` and the CI formatting check finish.
2. **Members are joined by name**, not by position, so a swapped pair is no longer silent.
3. **A handle can be reused** by several shapes of the same action, such as the two shapes of `update_note`.

### Negative

1. **Every member is written twice**: once in the member list and once in the builder.
2. **A member listed but never read, or read but never listed, compiles**: the first is ignored, and the second raises `SchemaError` at parse time.
3. **Every existing tool schema is rewritten**.

### Mitigations

- Each tool schema already has a test that parses a complete input and checks every field of the result; it now also catches a member that was listed but not read, or read but not listed.
- The migration is mechanical and is done tool by tool, each in its own commit, before the curried builder is removed.

## References

- [ADR-003](./adr-003-typed-schema-dsl.md) — the schema DSL this ADR refines.
- [ADR-005](./adr-005-tool-surface.md) — the tools whose schemas are rewritten.
