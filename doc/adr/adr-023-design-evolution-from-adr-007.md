# ADR-023: Design Evolution from ADR-007

## Status

Accepted (refined by [ADR-032](./adr-032-design-evolution-from-adr-023.md))

## Context

[ADR-007](./adr-007-error-handling.md) gave `RedmineError` two cases, `Response` for a non-2xx answer and `Transport` for everything without an HTTP status, decoding included, and mapped `Transport` to `status: 0` in the tool payload.

Running against Redmine 7.0.2 showed what that grouping costs.
When Redmine answers 2xx but the SDK cannot read the body, a model receives `{"status":0,...}`, the same payload as a refused connection or a TLS failure, and reads it as a network problem.
The commonest way to hit this is a proxy or single sign-on gateway in front of Redmine that answers a request with a 200 HTML login page, which the SDK reported as `invalid JSON in response: ...`.
A body whose shape differs from what the SDK expects was reported as `unexpected response shape: JsonDecodeError((/1, ...))`, and a relation type added by a plugin as `unknown relation type` without the value.

This ADR records the split of the decoding failures out of `Transport`, so that ADR-007's two-case design is not followed after it was refined.

## Design Changes from ADR-007

### 1. A 2xx answer that cannot be read raises `Decode`

#### Original Design (ADR-007)

`Transport` is everything without an HTTP status: connection, TLS, or decoding.

#### Revised Design

`RedmineError` gains a third case.

```moonbit
pub(all) suberror RedmineError {
  Response(status~ : Int32, errors~ : Array[String])
  Decode(message~ : String)
  Transport(message~ : String)
}
```

`Decode` is raised when the server answered 2xx but the body could not be read: a body that is not JSON, an envelope without its expected key, or a value whose shape does not match the type it decodes into.
`Transport` keeps the failures where no usable answer arrived: connection, TLS, an unusable endpoint, and a download's redirects.
`omochice/redmine-plugins` decodes plugin answers the same way and raises `Decode` too.

#### Rationale

Whether Redmine was reached is the first thing a caller needs to know to act on a failure, and only a separate case lets a caller of the SDK match on it.
Adding a case to a `pub(all)` suberror breaks every exhaustive match outside the SDK; that cost is paid once, while the misleading grouping would be paid on every such failure.

### 2. `Decode` carries no HTTP status

#### Revised Design

`Decode` holds a message only.
Its message opens with `The server answered, but the response could not be read`, followed by the cause:

- for a body that is not JSON, that the endpoint may point at something other than Redmine's API, such as a proxy or a login page;
- for an envelope without its key, the key;
- for a shape mismatch, the decoder's reason and the JSON path, such as ``Int::from_json: expected number at `/issues/0/id` ``;
- for an unknown relation type, the wire value Redmine sent.

#### Rationale

By the time a body is decoded, the classification of the exchange has already returned the JSON and the status is gone.
Threading the status through `send` and every decode call site would carry a value that is always 2xx, so the message states that the server answered instead.
ADR-007's rule that nothing from the request leaks into an error extends to the response: the message never quotes the body, so the JSON parser's own message, which quotes a character of the body, is dropped.

### 3. redmoon maps `Decode` to `status: 0`

#### Original Design (ADR-007)

`Transport(message)` maps to `status: 0` with `[message]`, and `status: 0` marks every failure that did not come from Redmine.

#### Revised Design

`Decode(message)` maps to `status: 0` with `[message]`, like `Transport`.

| Error                      | `status` | `errors`    |
| -------------------------- | -------- | ----------- |
| `Response(status, errors)` | `status` | `errors`    |
| `Decode(message)`          | `0`      | `[message]` |
| `Transport(message)`       | `0`      | `[message]` |

`status: 0` now means that the failure has no usable HTTP error status, and the message tells whether the server answered.

#### Rationale

The payload shape stays the one ADR-005 fixed, and a model already reads the message to learn what went wrong.
Reporting the 2xx status instead of 0 would present a failure as a success code.

## Consequences

### Positive

1. **A caller of the SDK can tell an unreadable answer from an unreachable Redmine** by matching on the case.
2. **A model is pointed at the likely cause** of a 2xx HTML page instead of at the network.
3. **A shape mismatch names where it occurred**, which narrows down the Redmine version or plugin that changed the answer.

### Negative

1. **Every exhaustive match on `RedmineError` outside the SDK breaks** and has to handle `Decode`.
2. **`status: 0` no longer means that Redmine was not reached**, so a model has to read the message to know.

### Mitigations

- The change is released as a breaking change, so the release notes name the new case a caller has to handle.
- Every `Decode` message opens with the same sentence, which a model reads as the distinction ADR-007 gave to `status: 0`.

## References

- [ADR-007](./adr-007-error-handling.md) — the decision this ADR refines.
- [ADR-005](./adr-005-tool-surface.md) — the failure payload.
- [ADR-025](./adr-025-redmineup-agile-data.md) — the plugin decoder, which reported a shape mismatch as `Transport`.
