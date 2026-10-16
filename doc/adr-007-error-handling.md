# ADR-007: Typed `raise` in the SDKs, `{status, errors}` at the Tool Boundary

## Status

Proposed

## Context

denomine-mcp spent two ADRs on how a failed Redmine call reaches the model.
Its ADR-0002 chose a Result-returning library variant so that every call site branches explicitly and nothing is swallowed; when the library became throw-only, its ADR-0008 wrapped each call in `Result.try` to keep that boundary.
The payload the model receives is `{ status, errors }`: the HTTP status and Redmine's `errors` array, with headers and the API key excluded.

MoonBit has checked errors.
A function that can fail declares `raise E` in its signature, the compiler rejects a caller that neither handles nor declares it, and `try ... catch` handles it.
The error that motivated the Result in TypeScript, an exception escaping unnoticed, cannot happen.

The two styles were compared in the C that moonc v0.10.15 generates with `--target native --release`.
A `raise` function returns a stack struct `{ int tag; union { ok; err } }` by value, allocating only the error value on failure.
A `Result` function allocates an `Ok` box on every success and two objects on failure.

## Decision Drivers

- **No failure goes unnoticed**: the reason denomine-mcp chose Results.
- **Idiomatic SDK**: the published modules read like MoonBit.
- **Safe payload**: no header or credential reaches the model.

## Considered Options

### Option 1: SDKs return `Result[T, E]`

**Pros:**

- Mirrors denomine-mcp's port types.

**Cons:**

- Allocates on every success, and is not how MoonBit libraries report errors.

### Option 2: SDKs `raise` a typed error (chosen)

**Pros:**

- The compiler enforces handling, success allocates nothing, and the signature names the error type.

**Cons:**

- A caller that wants a value to store has to convert it itself.

## Decision

We will have each SDK raise its own error type and have redmoon convert errors to the tool payload in one place.

### 1. Each SDK raises one error type

```moonbit
pub suberror RedmineError {
  Response(status~ : Int, errors~ : Array[String])
  Transport(message~ : String)
}
```

`Response` is a non-2xx answer, with `errors` read from Redmine's JSON body or empty when the body has none.
`Transport` is everything without an HTTP status: connection, TLS, or decoding.
`omochice/keyring` and `omochice/schema` likewise raise `KeyringError` and `SchemaError`.

**Rationale**: a caller matches on the cases it cares about, and the type in the signature tells it what can fail without reading the implementation.

### 2. redmoon maps every error to `{status, errors}` once

| Error                      | `status` | `errors`                         |
| -------------------------- | -------- | -------------------------------- |
| `Response(status, errors)` | `status` | `errors`                         |
| `Transport(message)`       | `0`      | `[message]`                      |
| `SchemaError`              | `0`      | `["<action>.<path>: <message>"]` |
| a local file error         | `0`      | `[message]`                      |

**Rationale**: this is denomine-mcp's payload, kept in one function so the shape cannot differ between tools.

### 3. Nothing from the request leaks into an error

No error case holds headers, the request URL with its query, or the API key.

**Rationale**: the error text reaches the model, and the API key is in a header of every request.

## Consequences

### Positive

1. **Handling is enforced by the compiler**, the guarantee denomine-mcp built by hand.
2. **No allocation on success**.
3. **One payload shape** for every tool.

### Negative

1. **The payload loses the error's type**: a model sees a status and strings, not which case occurred.
2. **`Transport` messages come from lower layers**, whose wording redmoon does not control.

### Mitigations

- `status: 0` marks every failure that did not come from Redmine, which is the distinction a model can act on.
- A transport message is passed through as is, and a test checks that an error from a request with an API key does not contain the key.

## References

- [MoonBit error handling](https://docs.moonbitlang.com/en/latest/language/error-handling.html)
- [ADR-005](./adr-005-tool-surface.md) — the result and failure payload.
- [ADR-006](./adr-006-typed-redmine-sdk.md) — the SDK that raises `RedmineError`.
