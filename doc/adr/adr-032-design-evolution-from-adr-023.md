# ADR-032: Design Evolution from ADR-023

## Status

Accepted

## Context

[ADR-023](./adr-023-design-evolution-from-adr-007.md) gave `RedmineError` three cases: `Response` for a non-2xx answer, `Decode` for a 2xx answer that cannot be read, and `Transport` for the failures where no usable answer arrived.

[ADR-030](./adr-030-additional-tags-issue-tags.md) then added a package that checks its arguments before it sends anything: a tag name that is blank or contains a comma, or an empty list of names, is rejected before any request, because the plugin would split or drop it.
The package raised that rejection as `Transport`, since neither of the other two cases fit, while ADR-023 defines `Transport` as a connection, TLS, endpoint, or redirect failure.
A caller matching on `Transport` to retry or to report an unreachable Redmine would then retry or report a request that was never sent.

This ADR records the case added for a request the SDK refuses to send, so that ADR-023's three-case design is not followed after it was refined.

## Design Changes from ADR-023

### 1. A request the SDK refuses to send raises `InvalidArgument`

#### Original Design (ADR-023)

`RedmineError` has the cases `Response`, `Decode`, and `Transport`, and a rejection before any request has no case of its own.

#### Revised Design

`RedmineError` gains a fourth case.

```moonbit
pub(all) suberror RedmineError {
  Response(status~ : Int32, errors~ : Array[String])
  Decode(message~ : String)
  Transport(message~ : String)
  InvalidArgument(message~ : String)
}
```

`InvalidArgument` is raised when the SDK refuses to send a request because an argument cannot be sent as asked, such as a tag name the plugin would split at a comma.
It is raised before anything is sent, so Redmine was neither reached nor answered.
`Transport` keeps the failures where no usable answer arrived, as ADR-023 defines it.

#### Rationale

A caller handles an unreachable Redmine and a refused argument differently: the first may be retried or reported as an outage, the second has to be corrected by the caller.
Only a separate case lets a caller of the SDK match on that distinction, which is the same reason ADR-023 split `Decode` out of `Transport`.
Widening the definition of `Transport` to cover pre-request rejection was rejected because every other `Transport` site in the SDK matches ADR-023's definition, and a message is the only way a caller could then tell the two apart.

### 2. redmoon maps `InvalidArgument` to `status: 0`

#### Original Design (ADR-023)

`Decode` and `Transport` map to `status: 0` with `[message]`.

#### Revised Design

`InvalidArgument(message)` maps to `status: 0` with `[message]`, like `Decode` and `Transport`.

| Error                       | `status` | `errors`    |
| --------------------------- | -------- | ----------- |
| `Response(status, errors)`  | `status` | `errors`    |
| `Decode(message)`           | `0`      | `[message]` |
| `Transport(message)`        | `0`      | `[message]` |
| `InvalidArgument(message)`  | `0`      | `[message]` |

#### Rationale

ADR-030 already fixes `status: 0` for an argument rejected before any request at the tool level, and the tool's own schema rejects the same arguments before the SDK sees them, so the mapping keeps the payload a model receives unchanged.
The payload shape stays the one ADR-005 fixed, and a model reads the message to learn what went wrong.

## Consequences

### Positive

1. **A caller of the SDK can tell a refused request from an unreachable Redmine** by matching on the case.
2. **`Transport` means what ADR-023 says it means** at every site that raises it.

### Negative

1. **Every exhaustive match on `RedmineError` outside the SDK breaks** and has to handle `InvalidArgument`.

### Mitigations

- The change is released as a breaking change, so the release notes name the new case a caller has to handle.
- `InvalidArgument` carries a message only, like `Decode` and `Transport`, so a caller that reports messages handles it with the same arm.

## References

- [ADR-023](./adr-023-design-evolution-from-adr-007.md) — the decision this ADR refines.
- [ADR-007](./adr-007-error-handling.md) — the original error type and the rule that nothing from the request leaks into an error.
- [ADR-030](./adr-030-additional-tags-issue-tags.md) — the validated tag names that first needed the case.
