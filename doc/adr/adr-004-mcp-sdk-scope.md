# ADR-004: MCP SDK as a Dual-Era Tool Server over stdio

## Status

Proposed

## Context

redmoon runs as a local process started by an MCP client such as Claude Desktop or Claude Code, which speaks JSON-RPC 2.0 to it over stdin and stdout.
On the stdio transport each message is one line of JSON, the server writes nothing to stdout that is not an MCP message, and closing stdin is the graceful shutdown signal.

The MCP specification changed shape with revision `2026-07-28`.
Up to `2025-11-25`, a client opened a session with an `initialize` request, the server answered with one protocol version, and later requests relied on that session.
From `2026-07-28` the protocol is stateless: every request carries `io.modelcontextprotocol/protocolVersion` and `io.modelcontextprotocol/clientCapabilities` in `params._meta`, every result carries `resultType`, and a server implements `server/discover` instead of `initialize`.
The specification calls the two kinds of implementation legacy and modern, and an implementation that answers both dual-era.

denomine-mcp was built on the official TypeScript SDK at revision `2025-11-25` and uses only tools.
Clients in use today still include ones that send `initialize`, and a legacy client has no way to move forward to a modern server: per the specification's compatibility matrix, a legacy client against a modern-only server fails.

No MoonBit MCP SDK was adopted; [ADR-001](./adr-001-five-module-moonbit-workspace.md) records why `omochice/mcp` is written here.

## Decision Drivers

- **Works with the clients in use**: Claude Desktop and Claude Code, whichever era they speak.
- **Follows the current specification**: a modern client is served by the modern rules.
- **Small surface**: the SDK covers what a stdio tool server needs and nothing redmoon does not use.

## Considered Options

### Option 1: Legacy only, `2025-11-25`

**Pros:**

- One lifecycle, identical to what denomine-mcp speaks.

**Cons:**

- A modern-only client cannot use the server, and the SDK is outdated on release.

### Option 2: Modern only, `2026-07-28`

**Pros:**

- No session state at all.

**Cons:**

- Every legacy client fails at `initialize`, with no fallback on its side.

### Option 3: Dual-era (chosen)

**Pros:**

- Both kinds of client work, and the modern path follows the current revision.

**Cons:**

- Two ways of establishing the protocol version in one server.

## Decision

We will implement `omochice/mcp` as a dual-era server that offers tools over stdio and nothing else.

### 1. Protocol versions

| Era    | Versions                                               |
| ------ | ------------------------------------------------------ |
| Modern | `2026-07-28`                                           |
| Legacy | `2025-11-25`, `2025-06-18`, `2025-03-26`, `2024-11-05` |

The supported versions are one constant list.

**Rationale**: the tools subset redmoon uses — `tools/list`, `tools/call`, and text content — reads the same in every listed revision, so accepting the older ones costs nothing and keeps older clients working.

### 2. How each request finds its era

| Incoming message                                                | Handling                                                                                                                                                                                                                                                          |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `initialize`                                                    | Legacy. Answers with the requested version when it is a supported legacy version, otherwise with `2025-11-25`, plus `capabilities: { tools: {} }` and `serverInfo`. The answered version applies to later requests on this process that carry no `_meta` version. |
| `notifications/initialized`                                     | Accepted, no answer.                                                                                                                                                                                                                                              |
| `ping`                                                          | Answers with an empty result.                                                                                                                                                                                                                                     |
| a request whose `_meta` names a modern version                  | Modern. Served by the rules of that version, with `resultType: "complete"` and `io.modelcontextprotocol/serverInfo` in the result's `_meta`.                                                                                                                      |
| a request whose `_meta` names a version not in the list         | Error `-32022` with `data.supported` and `data.requested`.                                                                                                                                                                                                        |
| a request with neither `_meta` version nor a prior `initialize` | Error `-32602`, since the request is missing required fields.                                                                                                                                                                                                     |

`server/discover` answers with `supportedVersions`, `capabilities: { tools: {} }`, and `serverInfo`.

**Rationale**: the specification has a dual-era server pick its behaviour from how the client opens, so a legacy client is recognized by its `initialize` and a modern one by its `_meta`, and neither is asked to change.

### 3. Tools

```moonbit
pub fn[T] tool(
  name : String,
  description : String,
  input : @schema.Schema[T],
  handler : async (T) -> ToolResult,
) -> Tool
```

`Tool` hides `T`, so tools with different argument types sit in one array, and `tools/list` returns them in registration order.
A call to an unknown tool is a JSON-RPC error `-32602`.
An argument that fails validation, and any failure inside a handler, is a tool result with `isError: true`.

**Rationale**: the specification separates protocol errors, which a model can rarely fix, from tool execution errors, which carry feedback it can act on.
denomine-mcp answered an unknown tool as a tool result; redmoon follows the specification instead, because a well-behaved client never sends a name it was not given.

### 4. Concurrency, cancellation, and shutdown

Each request runs in its own task in one `moonbitlang/async` task group, and writes to stdout are serialized.
`notifications/cancelled` cancels the task for that request id, and no response is written for it.
End of stdin ends the server once in-flight requests have finished.

**Rationale**: the specification has a server stop a cancelled request and send nothing more for it, which needs the request to be its own task; a server run one request at a time could only ignore the notification.

### 5. Only protocol output on stdout

The SDK writes protocol messages to stdout and nothing else, and diagnostics go to stderr.

**Rationale**: a single stray line on stdout is read by the client as a malformed message.

## Consequences

### Positive

1. **Both client eras work**: legacy clients through `initialize`, modern ones per request.
2. **Small SDK**: only tools, discovery, ping, and cancellation.
3. **Usable alone**: another MoonBit tool server can depend on `omochice/mcp` and `omochice/schema` only.

### Negative

1. **Two paths for one concern**: the protocol version comes either from `initialize` or from `_meta`, and both have to be tested.
2. **Partial protocol**: resources, prompts, progress, logging, subscriptions, multi round-trip requests, `structuredContent`, and the HTTP transport are missing.
3. **Specification tracked by hand**: a new revision is not picked up from an upstream SDK.

### Mitigations

- The era decision is one function from the incoming message and the process's legacy version, tested against each row of the table above.
- The module README lists what is supported, so a user knows the gaps before depending on it.
- The supported versions are one constant, so adding a revision is one change plus its tests.

## References

- [MCP 2026-07-28: Versioning and Compatibility](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning)
- [MCP 2026-07-28: stdio transport](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio)
- [MCP 2026-07-28: Discovery](https://modelcontextprotocol.io/specification/2026-07-28/server/discover)
- [MCP 2026-07-28: Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools)
- [MCP 2025-11-25: Lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
- [ADR-003](./adr-003-typed-schema-dsl.md) — the `Schema[T]` a tool takes.
- [ADR-005](./adr-005-tool-surface.md) — the tools redmoon registers.
