# ADR-016: Design Evolution from ADR-006

## Status

Proposed

## Context

[ADR-006](./adr-006-typed-redmine-sdk.md) decided that `omochice/redmine` is a typed client, and the first version put every resource into one package as methods on one `Redmine` type, mirroring `@omochice/redmine`'s class.
That package grew to 33 public methods and 47 public types.
Because a MoonBit package is one namespace, types of different resources had to be told apart by prefixes: `Attachment`, `IssueAttachment`, and `WikiAttachment` coexist, as do `IssueStatus`, `TimeEntryIssue`, and `TimeEntryCustomField`.
Helpers that consumers should not depend on, such as URL parsing and paging, were private only because they shared the package with everything else.

MoonBit offers two mechanisms that bear on this, both checked with moonc v0.10.15:

- A package under an `internal/` directory can be imported only by the package that contains that directory and its descendants; an import from another module fails with `Cannot import internal package ... due to internal visibility rules`.
- The pipe `x |> f(a)` passes `x` as the first argument of `f`, and it works with labelled and optional arguments and with `async` functions that `raise`:

```moonbit
redmine |> @issues.list(limit=3)
redmine |> @issues.show(42)
```

A public type alias of an internal type can be named from outside, but its constructors cannot: matching `@sdk.RedmineError::Response(..)` through an alias failed with `RedmineError is an alias to a type in .../internal/core, which is not imported`.
A type that consumers pattern-match therefore cannot live in an internal package.

## Design Changes from ADR-006

### 1. One package per resource, with functions that take the client first

**Original Design (ADR-006)**: every operation is a method of `Redmine` in one package.

```moonbit
redmine.list_issues(query, limit=10)
redmine.show_wiki_page(project, title)
```

**Revised Design**: each resource is its own package, and each operation is a function whose first parameter is the client, so calls read as a pipeline and the package names the resource.

```moonbit
redmine |> @issues.list(query, limit=10)
redmine |> @wiki.show(project, title)
```

| Package                                                                                           | Contents                                                                                                                            |
| ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `omochice/redmine`                                                                                | `Redmine`, `new`, `RedmineError`, `send`, `connection`, and types shared by several resources (`IdName`, `ProjectRef`, `Clearable`) |
| `omochice/redmine/issues`                                                                         | issues and journals, `Issue`, `Attachment`, `Journal`, date filters                                                                 |
| `omochice/redmine/wiki`                                                                           | wiki pages, `Page`                                                                                                                  |
| `omochice/redmine/versions`, `relations`, `search`, `time_entries`, `enumerations`, `attachments` | one resource each                                                                                                                   |
| `omochice/redmine/internal/core`                                                                  | the connection: endpoint, API key, opening HTTP clients, interpreting responses                                                     |
| `omochice/redmine/internal/wire`                                                                  | URL parsing and resolution, query encoding, `null` removal, error-body reading                                                      |
| `omochice/redmine/internal/paging`                                                                | the paged-list walk                                                                                                                 |

**Rationale**: the package becomes the namespace, so `@issues.Attachment` and `@wiki.Attachment` need no prefixes, and helpers move out of the public surface into `internal`, which the compiler enforces.
The pipe gives the method-call reading order without one type owning every operation.

### 2. Only `send` is public; the streaming transport is internal

**Original Design (ADR-006)**: the request functions are private to the single package.

**Revised Design**: `@redmine.send` (a JSON request) is public, documented as the way to call an endpoint the SDK does not cover yet.
The connection, which holds the endpoint and the API key and opens HTTP clients for the streamed attachment transfers, lives in `internal/core`.
`Redmine` stays a struct of the root package that holds the connection privately, and `@redmine.connection` hands it to the SDK's own resource packages; outside the module its result is unusable, because calling anything on it fails with `package ... internal/core is not imported`.

```text
pub struct Redmine { // private fields }
pub fn connection(Redmine) -> @core.Connection
pub fn new(endpoint~ : String, api_key~ : String) -> Redmine raise RedmineError
pub async fn send(Redmine, @http.RequestMethod, Array[String], query? : Array[(String, String)], body? : Json) -> Json raise RedmineError
```

**Rationale**: resource packages are separate packages and must reach the connection, while consumers should see only the operations they need.
`RedmineError` stays in the root because consumers pattern-match it, and constructors cannot be matched through an alias of an internal type, so `internal/core` reports failures without naming it and each caller converts them.
Making `Redmine` an alias of the internal connection was rejected because the internal path would then appear in every type error and in the generated interface; with a root struct it appears only in the return type of `connection`.
Keeping `send` public turns the one unavoidable exposure into a supported escape hatch.

## Consequences

### Positive

1. **No prefixed names**: types are named by what they are within their resource.
2. **Helpers are hidden by the compiler**, not by convention.
3. **Uncovered endpoints are reachable** through `send`.

### Negative

1. **`send` is part of the public API**, so changing its signature is a breaking change for consumers that use it.
2. **`connection` shows an internal type** in the generated interface, though nothing can be done with it outside the module.
3. **More imports**: a consumer imports one package per resource it uses.
4. **Every caller is rewritten**, including all redmoon tools.

### Mitigations

- `send`'s signature is kept small (method, path segments, query, optional body) and documented as low level.
- `connection` is documented as existing for the SDK's own packages.
- The redmoon tools are migrated in the same change, so the workspace never has two SDK shapes.

## References

- [ADR-006](./adr-006-typed-redmine-sdk.md) — the SDK this ADR refines.
- [ADR-012](./adr-012-design-evolution-from-adr-006.md) — the earlier refinement of ADR-006.
- [MoonBit: Managing Projects with Packages](https://docs.moonbitlang.com/en/latest/language/packages.html) — internal packages.
