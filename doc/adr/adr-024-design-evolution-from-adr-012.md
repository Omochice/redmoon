# ADR-024: Design Evolution from ADR-012

## Status

Superseded by [ADR-026](./adr-026-typed-redmine-sdk.md)

## Context

[ADR-012](./adr-012-design-evolution-from-adr-006.md) §1 kept `Attachment.filesize` a 32-bit `Int`, decoded by `derive(FromJson)`, because `Int64`'s `FromJson` in MoonBit core accepts only a JSON string and its `ToJson` writes one.
It accepted that attachments of 2 GiB or more fail to decode, and planned to widen the field once core's `Int64` decodes JSON numbers.

Redmine stores `attachments.filesize` as a `bigint` and puts no upper bound on `attachment_max_size`, so such an attachment is legal, and the failure turned out wider than ADR-012 expected.
An issue or wiki page embeds its attachments, so one file above 2 GiB makes `show` of that record fail, and makes `list` with `include: ["attachments"]` fail for every issue on the page.
`download` reads the metadata first, so it fails too, and the tool's `max_size` was an `Int32` that could never allow such a download even after decoding was fixed.
moonc v0.10.17 still encodes and decodes `Int64` as a string.

This ADR records how the SDK and the tool now handle sizes above 2 GiB, so that ADR-012's 32-bit field and its plan to wait for core are not followed.

## Design Changes from ADR-012

### 1. Attachment sizes are a `ByteSize` with its own number codec

#### Original Design (ADR-012)

`Attachment.filesize` is `Int` (32-bit), read from Redmine's JSON number by the derived decoder, and written back as a number.

#### Revised Design

`Attachment.filesize` is a `ByteSize`, a newtype over `Int64` in the attachments package.
`ByteSize` has a hand-written `FromJson` that reads a non-negative integer JSON number and rejects a string, a fraction, or a negative value, and a `ToJson` that writes `Json::number(self.0.to_double())`.
`Attachment` keeps `derive(FromJson, ToJson, Eq, Debug)`.

```moonbit
pub(all) struct ByteSize(Int64) derive(Eq, Debug)

pub fn ByteSize::to_int64(self : ByteSize) -> Int64
```

The SDK reports the size as Redmine sends it and imposes no limit of its own; how large a download may be is still decided by the caller.

#### Rationale

Waiting for core leaves a legal Redmine state unreadable, and the failure is not confined to the large attachment itself but takes down every record and list that embeds it.
A hand-written codec for the whole of `Attachment` was weighed against the wrapper type.
The wrapper confines the custom code to the one field that needs it, so `Attachment` stays derived like every other SDK type, and a field added to it later needs no codec change.
The price is that a caller reads the byte count through `to_int64()` instead of the field itself.

### 2. The download limit `max_size` is `Int64`

#### Original Design (ADR-012)

`max_size` is not named; the tool parsed it with `@schema.integer`, an `Int32`, with a 500 MiB default.

#### Revised Design

`omochice/schema` gains `integer64(min?, max?) -> Schema[Int64]`, which reads a JSON number, advertises `"type": "integer"`, and writes its bounds as numbers.
The tool parses `max_size` with it and keeps the 500 MiB default.
`optional_or` advertises its default with the value's `ToJson`, which for `Int64` would be a string, so redmoon wraps the limit in a private newtype whose `ToJson` writes a number.

```moonbit
priv struct ByteLimit(Int64)

impl ToJson for ByteLimit with fn to_json(self) {
  Json::number(self.0.to_double())
}
```

#### Rationale

An attachment that can now be read could still never be downloaded while the limit stayed below 2 GiB.
The limit is redmoon's decision rather than a size Redmine reports, so it does not reuse the SDK's `ByteSize`.
The newtype keeps the workaround for core's `Int64` encoding inside redmoon, so `omochice/schema` gains only the integer schema and `optional_or` keeps its meaning for every other caller.

## Consequences

### Positive

1. **Attachments of any size Redmine accepts decode**, so issue and wiki responses that embed them no longer fail.
2. **A model can allow a download above 2 GiB** by passing a larger `max_size`, while the default stays 500 MiB.
3. **Sizes stay JSON numbers** in the tool output and the advertised schema.
4. **`Attachment` keeps its derived codec**, like the other SDK types.

### Negative

1. **`Attachment.filesize` changed type**, which breaks callers of `omochice/redmine` that read it as an `Int32`.
2. **Callers unwrap the size with `to_int64()`** wherever they compare or compute with it.
3. **Sizes are written through a `Double`**, so the number in the output is exact only up to 2^53 bytes, about 9 PB.

### Mitigations

- The compiler points at every call site the type change breaks, and each fix is a `to_int64()` call.
- 2^53 bytes is far beyond any attachment Redmine can store in practice; `Json::number` takes a `repr` that would make larger values exact if that ever matters.
- Once core's `Int64` reads and writes JSON numbers, `ByteSize` and `ByteLimit` can give way to plain `Int64` fields.

## References

- [ADR-012](./adr-012-design-evolution-from-adr-006.md) — the decision this ADR refines.
- [ADR-006](./adr-006-typed-redmine-sdk.md) — the typed SDK whose responses `Attachment` belongs to.
- [ADR-003](./adr-003-typed-schema-dsl.md) — the schema DSL that `integer64` extends.
