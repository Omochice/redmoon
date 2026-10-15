# ADR-006: A Typed Redmine SDK on moonbitlang/async

## Status

Proposed

## Context

denomine-mcp reaches Redmine through `@omochice/redmine`, which validates every response with valibot, converts its keys to camelCase, and drops fields its schemas do not name.
redmoon needs the same reach from MoonBit, and [ADR-001](./adr-001-five-module-moonbit-workspace.md) makes the client a module of its own, `omochice/redmine`, meant to be published.

Several behaviours of denomine-mcp are decided by that library rather than by denomine-mcp, and were read from its source at v3.7.0:

- A list walks every page of 100 items; with `limit` it walks pages until that many items have been returned, then stops.
- An issue date filter is sent as a Redmine operator: `=2026-01-01`, `>=`, `<=`, `><2026-01-01|2026-01-31`, `t-3`, `t+3`, `>t-7`, `><t-7`, `<t-7`, `>t+7`, `><t+7`, `<t+7`, and `t`, `ld`, `w`, `lw`, `l2w`, `m`, `lm`, `y`, `*`, `!*`, `nd`, `nw`, `nm` for the named periods.
- The endpoint may carry a base path, and request paths are appended to it.
- An attachment download follows redirects by hand and sends the API key only to the endpoint's own origin.
- An upload posts the raw content to `/uploads.json` as `application/octet-stream` and returns the token.

`moonbitlang/async/http` provides the client: a request is started with `Client::request`, its body written as a stream, and the response body read as a stream.

MoonBit's `derive(FromJson, ToJson)` was probed with moonc v0.10.15.
It decodes a struct, leaves an `Option` field `None` when its key is missing, drops unknown keys, and omits a `None` field when encoding.
It fails on an `Option` field whose value is `null`: `JsonDecodeError((/assigned_to, Expected object to deserialize IdName))`.

## Decision Drivers

- **Publishable**: a consumer gets types to program against, not JSON to pick apart.
- **Same requests as denomine-mcp**: paging, date filters, base paths, and redirects behave as `@omochice/redmine` does.
- **Bounded memory**: attachment content of any size streams through.

## Considered Options

### Option 1: Typed input, `Json` output

**Pros:**

- Every field Redmine returns reaches the caller, with no output types to maintain.

**Cons:**

- A consumer of the published SDK has no types for what it reads.

### Option 2: Typed input and typed output (chosen)

**Pros:**

- The SDK is a complete library to publish, and the compiler checks every field access.

**Cons:**

- Every response shape has to be modelled, and unmodelled fields are dropped.

## Decision

We will write `omochice/redmine` with typed requests and typed responses.

### 1. Response types mirror Redmine's JSON

Each resource has structs whose field names are Redmine's snake_case keys, deriving `FromJson` and `ToJson`, unwrapped from Redmine's envelope (`{"issue": {...}}` becomes `Issue`).
A field Redmine may omit is an `Option`.

**Rationale**: matching names let `derive` do the decoding and let redmoon encode the value back with nothing renamed ([ADR-005](./adr-005-tool-surface.md)).

### 2. `null` is removed before decoding

Before a response is decoded, every object member whose value is `null` is removed, recursively.

**Rationale**: `derive(FromJson)` already reads a missing key as `None`, so removing `null` makes `null` and absence the same thing in one place, instead of a hand-written decoder per field or a wrapper type in every struct.

### 3. Clearing a field is its own case in update requests

```moonbit
pub enum Clearable[T] {
  Set(T)
  Clear
}

pub struct IssueUpdate {
  assigned_to_id : Clearable[Int]?
  ...
}
```

`None` leaves the field out of the request, `Some(Clear)` sends `null`, and `Some(Set(v))` sends `v`.

**Rationale**: Redmine reads a `null` in an update as "clear this field", so absence and `null` mean different things on the request side, and an `Option` alone cannot carry both.

### 4. Requests follow `@omochice/redmine`

Paging, `limit`, the date filter operators, base-path joining, manual redirects that keep the API key on the endpoint's origin, and the upload request are implemented as listed under Context.
Date filters are an enum whose cases are the filter forms denomine-mcp accepts, so a form Redmine rejects on a `:date_past` field is not constructible for it.

**Rationale**: these decide which issues a query returns, and a mistake still answers 200, so the operators are copied from the library rather than derived anew.

### 5. Attachment content streams

`download` returns the metadata and a reader over the body; `upload` takes a reader and its length.

**Rationale**: the content is never held whole in memory, so an attachment's size does not bound the process.

### 6. The first version covers what redmoon uses

Issues, journals, wiki pages, versions, issue relations, search, time entries, enumerations, attachments, and uploads.

**Rationale**: these are the endpoints with a user; the other resources of the REST API are added when something uses them.

## Consequences

### Positive

1. **A typed SDK to publish**: consumers program against structs and enums.
2. **Same queries as denomine-mcp**: a filter selects the same issues.
3. **Size-independent attachments**.

### Negative

1. **Unmodelled fields are dropped**, the same as with `@omochice/redmine`.
2. **Partial API coverage** in the first version.
3. **Explicit `null` and absence are merged** in responses, so a caller cannot tell "Redmine sent null" from "Redmine omitted the key".
4. **Copied logic**: the date operators and paging follow another library and drift if it changes.

### Mitigations

- The types follow the Redmine REST API documentation of each resource, and the integration tests decode real responses from the Redmine of `compose.yaml`, so a missing or wrong field shows up as a failing test.
- The module README lists the covered resources.
- Redmine's REST API gives no different meaning to an omitted key and a `null` value in a response, so nothing a caller can act on is lost.
- Each operator has a unit test pinning the exact query string.

## Implementation Notes

- That Redmine sends `null` for empty fields has not been checked yet; confirm it against the Redmine of `compose.yaml` before relying on decision 2.
- Requests use the `X-Redmine-API-Key` header, and the key never appears in an error.

## References

- [Redmine REST API](https://www.redmine.org/projects/redmine/wiki/Rest_api)
- [Omochice/deno-redmine v3.7.0](https://github.com/Omochice/deno-redmine/tree/v3.7.0) — `internal/paging.ts`, `issues/validator.ts`, `attachments/download.ts`, `files/upload.ts`.
- [ADR-007](./adr-007-error-handling.md) — how the SDK reports failures.
