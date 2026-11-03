# ADR-026: A Typed Redmine SDK of Per-Resource Packages on moonbitlang/async

## Status

Accepted

## Context

This ADR consolidates [ADR-006](./adr-006-typed-redmine-sdk.md) and the three ADRs that refined it, [ADR-012](./adr-012-design-evolution-from-adr-006.md), [ADR-016](./adr-016-design-evolution-from-adr-006.md), and [ADR-024](./adr-024-design-evolution-from-adr-012.md).
A reader had to follow all four in order to learn the SDK's current design, so this ADR restates that design as one decision and replaces them as the primary record.

denomine-mcp reaches Redmine through `@omochice/redmine`, which validates every response with valibot, converts its keys to camelCase, and drops fields its schemas do not name.
redmoon needs the same reach from MoonBit, and [ADR-001](./adr-001-five-module-moonbit-workspace.md) makes the client a module of its own, `omochice/redmine`, meant to be published.
Paging, date filters, base paths, redirects, and uploads in denomine-mcp are decided by that library rather than by denomine-mcp.

`moonbitlang/async/http` provides the HTTP client: a request is started with `Client::request`, its body written as a stream, and the response body read as a stream.

The design depends on the following properties of MoonBit, observed with moonc v0.10.15 and, for `Int64`, still true in v0.10.17:

- `derive(FromJson, ToJson)` decodes a struct, leaves an `Option` field `None` when its key is missing, drops unknown keys, and omits a `None` field when encoding.
- The derived decoder fails on an `Option` field whose value is `null`: `JsonDecodeError((/assigned_to, Expected object to deserialize IdName))`.
- `Int64`'s `FromJson` accepts only a JSON string and its `ToJson` writes one, while Redmine sends sizes as numbers.
- A package under an `internal/` directory can be imported only by the package that contains that directory and its descendants; an import from another module fails with `Cannot import internal package ... due to internal visibility rules`.
- The pipe `x |> f(a)` passes `x` as the first argument of `f`, and it works with labelled and optional arguments and with `async` functions that `raise`.
- A public type alias of an internal type can be named from outside, but its constructors cannot be matched: `RedmineError is an alias to a type in .../internal/core, which is not imported`.

Redmine itself bears on two choices.
It stores `attachments.filesize` as a `bigint` and puts no upper bound on `attachment_max_size`, so an attachment of 2 GiB or more is legal.
An issue or wiki page embeds its attachments, so a size the SDK cannot decode fails `show` of that record and every list page that includes it, not only the attachment itself.

## Decision Drivers

- **Publishable**: a consumer gets types to program against, not JSON to pick apart.
- **Same requests as denomine-mcp**: paging, date filters, base paths, and redirects behave as `@omochice/redmine` does.
- **Bounded memory**: attachment content of any size streams through.
- **Small public surface**: helpers that consumers are not meant to depend on are hidden by the compiler, not by convention.
- **Every legal Redmine state is readable**: a value Redmine accepts does not make a response undecodable.

## Considered Options

The options differ in what the SDK returns and in how its operations are grouped.

### Option 1: Typed input, `Json` output

#### Pros

- Every field Redmine returns reaches the caller, with no output types to maintain.

#### Cons

- A consumer of the published SDK has no types for what it reads.

### Option 2: Typed input and output, every operation a method of `Redmine` in one package

```moonbit
redmine.list_issues(query, limit=10)
redmine.show_wiki_page(project, title)
```

#### Pros

- Mirrors `@omochice/redmine`'s single class, and calls read as method calls.

#### Cons

- A MoonBit package is one namespace, so types of different resources have to be told apart by prefixes, such as `IssueStatus` and `TimeEntryIssue`.
- Helpers such as URL parsing and paging are private only because they share the package with everything else.

### Option 3: Typed input and output, one package per resource with client-first functions (chosen)

```moonbit
redmine |> @issues.list(query, limit=10)
redmine |> @wiki.show(project, title)
```

#### Pros

- The SDK is a complete library to publish, and the compiler checks every field access.
- The package names the resource, so types are named by what they are within it, and helpers live in `internal` packages.

#### Cons

- Every response shape has to be modelled, and unmodelled fields are dropped.
- A consumer imports one package per resource it uses.

## Decision

We will write `omochice/redmine` with typed requests and typed responses, one package per resource, whose functions take the client as their first argument.

### 1. Response types mirror Redmine's JSON

Each resource has structs whose field names are Redmine's snake_case keys, deriving `FromJson` and `ToJson`, unwrapped from Redmine's envelope (`{"issue": {...}}` becomes `Issue`).
A field Redmine may omit is an `Option`, and ids and counts are `Int32`.
Where Redmine sends a closed set of strings, such as a relation type or a version status, the type is an enum with a hand-written codec that maps the wire strings.

**Rationale**: matching names let `derive` do the decoding and let redmoon encode the value back with nothing renamed ([ADR-028](./adr-028-tool-surface.md)).

### 2. `null` is removed from answers before decoding

Before a 2xx response is decoded, every object member whose value is `null` is removed, recursively; array elements are kept as they are.
Request bodies are sent as they are given, so a `null` in a request reaches Redmine.

**Rationale**: `derive(FromJson)` already reads a missing key as `None`, so removing `null` makes `null` and absence the same thing in one place, instead of a hand-written decoder per field or a wrapper type in every struct.

### 3. Clearing a field is its own case in update requests

```moonbit
pub(all) enum Clearable[T] {
  Set(T)
  Clear
}

pub struct Update {
  assigned_to_id : @redmine.Clearable[Int32]?
  ...
}
```

`None` leaves the field out of the request, `Some(Clear)` sends `null`, and `Some(Set(v))` sends `v`.
`Clearable` lives in the root package so that every resource, and `omochice/redmine-plugins`, gives "leave alone", "empty", and "set" the same meaning.

**Rationale**: Redmine reads a `null` in an update as "clear this field", so absence and `null` mean different things on the request side, and an `Option` alone cannot carry both.

### 4. One package per resource, with functions that take the client first

Each resource is its own package, and each operation is a function whose first parameter is the client, so calls read as a pipeline and the package names the resource.
Helpers that consumers are not meant to depend on live in packages under `internal/`.
The root package `omochice/redmine` holds the client, `RedmineError`, `send`, and the types shared by several resources, such as `IdName`, `ProjectRef`, and `Clearable`.

**Rationale**: the package becomes the namespace, so `@issues.Parent` and `@wiki.Parent`, or `@issues.Issue` and `@time_entries.Issue`, need no prefixes, and helpers move out of the public surface into `internal`, which the compiler enforces.
The pipe gives the method-call reading order without one type owning every operation, which is why Option 2 was not kept.

### 5. Only `send` is offered for direct use; the transport is internal

`@redmine.send` sends one JSON request and returns the answer, and is documented as the way to call an endpoint the SDK does not cover yet.
The connection, which holds the endpoint and the API key and opens HTTP clients, lives in `internal/core`.
`Redmine` is a struct of the root package that holds the connection privately.
`connection` hands the connection to the SDK's own resource packages, and `unwrap` lets them turn a classified exchange into a `RedmineError` the way `send` does.
Both take or return a type of `internal/core`, so outside the module their results cannot be used and `unwrap` cannot be called.

**Rationale**: resource packages are separate packages and need the connection, while consumers see only the operations they need.
`RedmineError` stays in the root because consumers pattern-match it, and constructors cannot be matched through an alias of an internal type, so `internal/core` classifies an exchange without naming it and the root converts the classification.
Making `Redmine` an alias of the internal connection was rejected because the internal path would then appear in every type error and in the generated interface; with a root struct it appears only in the signatures of `connection` and `unwrap`.
Keeping `send` public turns the one unavoidable exposure into a supported escape hatch.

### 6. Failures are a `RedmineError`

Every SDK function raises `RedmineError`, whose cases are defined by [ADR-007](./adr-007-error-handling.md) as refined by [ADR-023](./adr-023-design-evolution-from-adr-007.md): `Response` for a non-2xx answer, `Decode` for a 2xx answer that cannot be read, and `Transport` for every failure without a usable answer.
Decoding goes through `internal/decode`, which reports a missing envelope key or a shape mismatch as `Decode` with the JSON path where it occurred.
Attachment downloads are the one exception, described in decision 8.

**Rationale**: the error type is its own decision, recorded in those ADRs; this ADR fixes only that the SDK reports every failure of its own through it.

### 7. Requests follow `@omochice/redmine`

The following request behaviours are copied from `@omochice/redmine` as read from its source at v3.7.0:

- A list is read in pages of 100 items.
  Without `limit`, the first page's `total_count` decides which further pages are requested; with it, pages are requested until that many items are collected or a page comes back short.
- An issue date filter is sent as one of the Redmine operators that the issue validator of `@omochice/redmine` accepts.
- The endpoint may carry a base path, and request paths are appended to it.
- An attachment download follows redirects by hand and sends the API key only to the endpoint's own origin.
- An upload posts the raw content to `/uploads.json` as `application/octet-stream` and returns the token.

Date filters are two enums, `PastDateFilter` for the fields Redmine types as `:date_past` and `DateFilter` for the fields typed as `:date`, so a forward-looking form that Redmine rejects on a `:date_past` field is not constructible for it.

**Rationale**: these decide which issues a query returns, and a mistake still answers 200, so the operators are copied from the library rather than derived anew.

### 8. Attachment content streams, and the consumer's errors pass through

`download` hands the metadata and a reader over the body to `consume`, and closes the connection when `consume` returns or raises.
The download's own failures are `RedmineError`, but an error raised by `consume` propagates unchanged, so the function's error type is the general `Error`.
`upload` takes a reader and its length and returns the token that attaches the content to a record.

**Rationale**: the content is never held whole in memory, so an attachment's size does not bound the process.
The SDK keeps the connection open only while `consume` runs, so the caller's own failures, such as an existing file or an exceeded size limit, happen inside the SDK's call and reach the caller as they were raised.
Wrapping them in `RedmineError` was rejected because it would make them look like Redmine's.

### 9. Attachment sizes are a `ByteSize` with its own number codec

`Attachment.filesize` is a `ByteSize`, a newtype over `Int64` in the attachments package that callers unwrap with `to_int64`.
Its hand-written `FromJson` reads a non-negative integer JSON number and rejects a string, a fraction, or a negative value, and its `ToJson` writes `Json::number(self.0.to_double())`, so a size written back is exact only up to 2^53 bytes, about 9 PB.
`Attachment` itself keeps `derive(FromJson, ToJson, Eq, Debug)`.
The SDK reports the size as Redmine sends it and imposes no limit of its own; how large a download may be is decided by the caller.

**Rationale**: a 32-bit `Int` leaves a legal Redmine state unreadable, and the failure is not confined to the large attachment but takes down every record and list that embeds it, while core's `Int64` cannot read the number Redmine sends.
A hand-written codec for the whole of `Attachment` was weighed against the wrapper type.
The wrapper confines the custom code to the one field that needs it, so a field added to `Attachment` later needs no codec change.
2^53 bytes is far beyond any attachment Redmine can store in practice, and once core's `Int64` reads and writes JSON numbers, `ByteSize` can give way to a plain `Int64` field.

### 10. The SDK covers what redmoon uses

The resource packages cover issues, journals, wiki pages, versions, issue relations, search, time entries, enumerations, attachments and uploads, project memberships ([ADR-028](./adr-028-tool-surface.md)), and saved issue queries.

**Rationale**: these are the endpoints with a user; the other resources of the REST API are added when something uses them, and `send` reaches them until then.

## Consequences

### Positive

Every Decision Driver is met, as the rationale of each decision states, so the gains are not repeated here.

### Negative

The decision accepts the following costs:

1. **Unmodelled fields are dropped**, the same as with `@omochice/redmine`.
2. **Partial API coverage**.
3. **Explicit `null` and absence are merged** in responses, so a caller cannot tell "Redmine sent null" from "Redmine omitted the key".
4. **Copied logic**: the date operators and paging follow another library and drift if it changes.
5. **`send` is part of the public API**, so changing its signature is a breaking change for consumers that use it.
6. **`connection` and `unwrap` show an internal type** in the generated interface, though nothing can be done with them outside the module.
7. **More imports**: a consumer imports one package per resource it uses.
8. **`download`'s signature does not name its error type**, unlike every other SDK function.

### Mitigations

The costs above are limited as follows:

- The types follow the Redmine REST API documentation of each resource, and the integration tests decode real responses from the Redmine of `compose.yaml`, so a missing or wrong field shows up as a failing test.
- Redmine's REST API gives no different meaning to an omitted key and a `null` value in a response, so nothing a caller can act on is lost.
- Each date operator has a unit test pinning the exact query string.
- `send`'s signature is kept small (method, path segments, query, optional body) and documented as low level, and `connection` and `unwrap` are documented as existing for the SDK's own packages.
- The documentation of `download` states which errors are `RedmineError` and that the callback's errors pass through.

## Implementation Notes

Requests carry the API key in the `X-Redmine-API-Key` header, and the key never appears in an error.

## References

- [ADR-006](./adr-006-typed-redmine-sdk.md), [ADR-012](./adr-012-design-evolution-from-adr-006.md), [ADR-016](./adr-016-design-evolution-from-adr-006.md), [ADR-024](./adr-024-design-evolution-from-adr-012.md) — the decisions this ADR consolidates and supersedes.
- [ADR-001](./adr-001-five-module-moonbit-workspace.md) — the module split that makes the SDK a module.
- [ADR-028](./adr-028-tool-surface.md) — the tools that return SDK values, and the download limit redmoon sets.
- [ADR-007](./adr-007-error-handling.md) and [ADR-023](./adr-023-design-evolution-from-adr-007.md) — the error type the SDK raises.
- [Redmine REST API](https://www.redmine.org/projects/redmine/wiki/Rest_api)
- [Omochice/deno-redmine v3.7.0](https://github.com/Omochice/deno-redmine/tree/v3.7.0) — `internal/paging.ts`, `issues/validator.ts`, `attachments/download.ts`, `files/upload.ts`.
- [MoonBit: Managing Projects with Packages](https://docs.moonbitlang.com/en/latest/language/packages.html) — internal packages.
