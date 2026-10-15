# ADR-012: Design Evolution from ADR-006

## Status

Proposed

## Context

[ADR-006](./adr-006-typed-redmine-sdk.md) decided that `omochice/redmine` has typed requests and typed responses, removes `null` before decoding, streams attachment content, and reproduces the requests of `@omochice/redmine` v3.7.0.
Implementing the resources against Redmine 7.0 found two places where the typed design meets a limit of MoonBit, and the implementation settled each one.
This ADR records them so that ADR-006 is not read as promising more than the SDK does.

## Design Changes from ADR-006

### 1. Attachment sizes are decoded as a JSON number into `Int`

**Original Design (ADR-006)**: response fields mirror Redmine's JSON through `derive(FromJson)`, without saying how large numbers are typed.

**Revised Design**: `Attachment.filesize` is `Int` (32-bit), read from Redmine's JSON number by the derived decoder, and written back as a number.

**Rationale**: in moonc v0.10.15, `Int64`'s `FromJson` accepts only a string, so an `Int64` field fails on the plain number Redmine sends, and its `ToJson` would change the number the tools return into a string.
Keeping the field a number on both sides was preferred over a hand-written decoder for one field, at the cost of the range below.

### 2. `download_attachment` raises an untyped error

**Original Design (ADR-006, with [ADR-007](./adr-007-error-handling.md))**: every SDK function raises `RedmineError`.

**Revised Design**:

```moonbit
pub async fn Redmine::download_attachment(
  self : Redmine,
  id : Int32,
  consume : async (Attachment, &@io.Reader) -> Unit,
) -> Unit
```

The download's own failures are still `RedmineError`, but an error raised by `consume` propagates unchanged, so the function's error type is the general `Error`.

**Rationale**: the SDK keeps the HTTP connection open only while `consume` runs, so the caller's own failures, such as an existing file or an exceeded size limit, happen inside the SDK's call and must reach the caller as they were raised; wrapping them in `RedmineError` would make them look like Redmine's.

## Consequences

### Positive

1. **Tool responses keep numbers as numbers**, and no field needs a hand-written decoder.
2. **Callers of `download_attachment` can tell their own failures from Redmine's** by matching the error.

### Negative

1. **Attachments of 2 GiB or more fail to decode**, so `show` and `download` reject them with a transport error.
2. **`download_attachment`'s signature does not name its error type**, unlike every other SDK function.

### Mitigations

- Redmine's default attachment size limit is 5 MiB and the tool's default `max_size` is 500 MiB, so instances near the 2 GiB limit are rare; the field can move to a wider type when MoonBit's `Int64` decodes JSON numbers.
- The function's documentation states which errors are `RedmineError` and that the callback's errors pass through.

## References

- [ADR-006](./adr-006-typed-redmine-sdk.md) — the decision this ADR refines.
- [ADR-007](./adr-007-error-handling.md) — the typed errors the SDK otherwise raises.
