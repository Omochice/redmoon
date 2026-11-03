# ADR-033: Design Evolution from ADR-004

## Status

Accepted

## Context

[ADR-004](./adr-004-mcp-sdk-scope.md) decided that `omochice/mcp` is a dual-era tool server over stdio, fixed the supported versions, and laid out in a table how each incoming message finds its era.

Implementing the server against the `2026-07-28` specification and the clients in use added behaviour the table does not mention, and settled two cases the table leaves open.
A client that validates results against the `2026-07-28` schema rejects a `tools/list` result without caching hints, so the server emits them; a modern request without `clientCapabilities` is refused; a request id that is already in flight is refused; `server/discover` is refused to a legacy session; `initialize` and `server/discover` can carry `instructions`.
The table also does not say which row wins when `ping` carries an unsupported `_meta` version, and the implementation keeps only whether `initialize` happened rather than the version it answered.
Finally, the `tool` signature in the ADR is positional while the implemented one is labelled.

This ADR records those refinements so that ADR-004 is read together with what the code does; decisions 1 and 5 of ADR-004 still hold as written.

## Design Changes from ADR-004

### 1. `instructions` can be given to the server

#### Original Design (ADR-004)

`initialize` answers with the negotiated version, `capabilities` and `serverInfo`; `server/discover` answers with `supportedVersions`, `capabilities` and `serverInfo`.

#### Revised Design

`Server::new` takes an optional `instructions` string.
When it is given, both answers carry it as `instructions`, unchanged.
redmoon does not pass it yet; its tool descriptions carry the guidance a model needs.

#### Rationale

`instructions` is the one field in both answers for guidance that applies to the server as a whole rather than to one tool, and it is a string sent as is, so offering it costs one optional argument.
It is kept although redmoon has no use for it today, because ADR-004 also decided the SDK is usable alone, and a tool server with cross-tool guidance has no other place to put it.

### 2. Modern results carry caching hints

#### Revised Design

A modern `tools/list` or `server/discover` result carries `ttlMs: 3600000` and `cacheScope: "public"`.
A legacy result carries neither.

#### Rationale

Clients that validate against the `2026-07-28` schema reject a list result without the hints.
The tool list is fixed at startup, so an hour is a safe lifetime, and the list is identical for every user of the server, so the scope is public.

### 3. A request id already in flight is refused

#### Original Design (ADR-004)

Each request runs in its own task, keyed by its id so that `notifications/cancelled` can find it.

#### Revised Design

A `tools/call` whose id is already in use by a request in flight is answered with `-32600` and is not run.

#### Rationale

JSON-RPC requires ids to be unique among the requests in flight, and the task map is keyed by id.
Running the second request would either lose the first task's handle, so its cancellation could no longer be delivered, or answer two results under one id.

### 4. A modern request must carry `clientCapabilities`

#### Original Design (ADR-004)

A request whose `_meta` names a modern version is served by the modern rules.

#### Revised Design

A request whose `_meta` names a modern version but has no `io.modelcontextprotocol/clientCapabilities` object is answered with `-32602`.

#### Rationale

The `2026-07-28` specification makes both `_meta` fields required on every modern request, so a request without the capabilities is missing a required field, which is what `-32602` means.

### 5. `server/discover` is refused to a legacy session

#### Original Design (ADR-004)

`server/discover` answers with `supportedVersions`, `capabilities` and `serverInfo`.

#### Revised Design

`server/discover` answers so only when the request resolves to the modern era.
When it resolves to the legacy era, whether because its `_meta` names a legacy version or because the process was opened with `initialize` and the request names no version, it is answered with `-32601`.

#### Rationale

`server/discover` does not exist in the legacy revisions, and a legacy client that reaches it would be told about a lifecycle it cannot use.
A legacy session sees the same answer as for any other method outside its revision.

### 6. The server keeps whether `initialize` happened, not the version it answered

#### Original Design (ADR-004)

The answered version applies to later requests on this process that carry no `_meta` version.

#### Revised Design

The server keeps a single `initialized : Bool`.
A later request without a `_meta` version is served by the legacy rules when `initialize` happened, whichever legacy version was answered.

#### Rationale

Every supported legacy version shares one wire shape for the tools subset the server offers, so keeping the version would select nothing.
The flag can become the version if a later legacy revision needs its own shape.

### 7. `ping` with an unsupported `_meta` version answers `-32022`

#### Original Design (ADR-004)

`ping` answers with an empty result, and a request whose `_meta` names a version not in the list answers `-32022`.

#### Revised Design

The version row wins.
`ping` answers a result with no fields of its own, in the shape of its era, whenever the era resolves or is merely unknown, and `-32022` with `data.supported` and `data.requested` when its `_meta` names a version the server does not support.

#### Rationale

A client probing with `ping` before opening a session learns from `-32022` which versions it can use, which an empty result would hide.
Every other failure to resolve the era, such as no `_meta` before `initialize`, still answers the empty result, because `ping` is meant to work before the session is open.

### 8. `tool` takes labelled arguments

#### Original Design (ADR-004)

```moonbit
pub fn[T] tool(
  name : String,
  description : String,
  input : @schema.Schema[T],
  handler : async (T) -> ToolResult,
) -> Tool
```

#### Revised Design

```moonbit
pub fn[T] tool(
  name~ : String,
  description~ : String,
  input~ : @schema.Schema[T],
  handler~ : async (T) -> ToolResult,
) -> Tool
```

#### Rationale

`name` and `description` are both strings, so a positional call could swap them without a compile error; labels make each argument visible at the call site.

## Consequences

### Positive

1. **Clients validating against `2026-07-28` accept the results**, since the required hints and the required request fields are enforced.
2. **A duplicate id cannot orphan a task**, so cancellation always reaches the request it names.
3. **The ADR and the code agree** on `ping`, `server/discover`, and the `tool` signature.

### Negative

1. **`instructions` is unused by redmoon**, so the SDK carries one feature its only user does not exercise.
2. **The caching hints are fixed**, so a server whose tool list changes at runtime would advertise a stale lifetime.

### Mitigations

- `instructions` is one optional argument and two `push` calls, and the test suite covers it, so the cost of keeping it is small.
- The tool list of this SDK is fixed at construction, so no server built on it can change the list at runtime.

## References

- [ADR-004](./adr-004-mcp-sdk-scope.md) — the decision this ADR refines.
- [MCP 2026-07-28: Versioning and Compatibility](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning)
- [MCP 2026-07-28: Discovery](https://modelcontextprotocol.io/specification/2026-07-28/server/discover)
- [MCP 2026-07-28: Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools)
- [MCP 2025-11-25: Lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
