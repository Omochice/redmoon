# ADR-045: Design Evolution from ADR-026

## Status

Accepted

## Context

[ADR-026](./adr-026-typed-redmine-sdk.md) keeps the helpers of `omochice/redmine` in packages under `internal/` and offers `send` as the one function for calling an endpoint the SDK does not cover.
[ADR-017](./adr-017-redmine-plugin-sdk-module.md) built `omochice/redmine-plugins` on `send`, and because another module cannot import an internal package, it gave that module its own copy of the decoding helper.
[ADR-030](./adr-030-additional-tags-issue-tags.md) added a copy of the paging helper beside it.
Both ADRs rejected widening the SDK's public surface and accepted the copies as small code with little reason to diverge.

`send` answers one request with raw JSON.
A caller that uses it still has to read that JSON into a type and report an answer it cannot read as a `Decode` error, and for a list it has to walk the pages.
Those two tasks are what the copies do, so the plugin module repeats them not because plugins differ from Redmine but because `send` alone is not enough to use.

The copies turned out to change for the same reason as the originals.

- The decoding helper decides how an unreadable answer is reported, which is part of the error type every SDK function raises.
  The copies are the same code with the same messages, and the one change made to the helper since the copy was taken was made to both in the same commit.
- The paging helper follows the list protocol of Redmine itself: the page size Redmine caps, the limit a caller asks for, and the total count that tells which pages remain.
  The plugin module uses its copy for one request, Redmine's own issue list with a tag filter, so that copy follows the same protocol.
  It had also grown well past the size ADR-017 accepted, and it carries rules a second implementation would have to get right again.

Code that changes for one reason in two places has to be fixed twice, and nothing reports a fix that reached only one of them.

This ADR records that the two helpers are now part of what the SDK offers; every other decision of ADR-026, ADR-017, and ADR-030 still holds as written.

## Design Changes from ADR-026

### 1. Decoding and paging are offered beside `send`

#### Original Design (ADR-026, Decisions 4 and 5)

Helpers that consumers are not meant to depend on live under `internal/`, the decoding and paging helpers among them, and only `send` is offered for direct use.

#### Revised Design

Decoding an answer and walking a paged list are public packages of `omochice/redmine`, `decode` and `paging`, which the resource packages use as before.
A caller of `send` reads its answer and lists through it the way the SDK does.

```moonbit
let json = redmine |> @redmine.send(Get, ["projects", "demo", "news.json"])
let news : Array[News] = @decode.decode_field(json, "news")
```

The connection and the request encoding stay under `internal/`.

#### Rationale

A helper belongs under `internal/` when a consumer has no use for it, and these two are needed by every consumer that calls `send`.
Hiding them did not stop consumers from depending on their behaviour; it made them write it again, as the plugin module shows.
The connection and the request encoding stay internal because `send` already covers what a consumer needs from them.

Moving the plugin packages into `omochice/redmine`, where they could import the internal packages, was rejected because ADR-017's reason for a separate module is untouched: the SDK of Redmine itself would describe APIs most instances do not serve.
Keeping the copies and comparing them in CI was rejected because it turns the duplication into a rule to maintain instead of removing it.

### 2. The plugin module uses the SDK's packages instead of copies

#### Original Design (ADR-017, Decision 1, and ADR-030, Decision 6)

`omochice/redmine-plugins` keeps its own `internal/decode`, and a copy of the paging helper in `internal/paging`.

#### Revised Design

The plugin packages import `decode` and `paging` from `omochice/redmine`, and the plugin module has no internal packages.

#### Rationale

With the packages public there is nothing left that a copy protects.
The plugin module still reaches Redmine only through `send`, since the paging package is built on it, so the boundary ADR-017 drew is unchanged.
ADR-030's refusal to let another module put parameters into a core request also stands: the shared walk adds only the page position to a request the caller wrote itself.

### Not Decided Here

- Whether a plugin endpoint that pages by a protocol of its own gets a walk in the plugin module is decided when such an endpoint is added.
- Whether other internal helpers become public is decided when a consumer of `send` is found repeating them.

## Consequences

### Positive

1. **One implementation**: a fix to decoding or paging reaches the SDK and every plugin package at once.
2. **`send` is usable on its own terms**: a consumer covering a missing endpoint reports an unreadable answer and pages a list exactly as the resource packages do.
3. **The plugin module holds only plugin knowledge**.

### Negative

1. **A larger public surface**: the signatures of the decoding and paging functions are now a compatibility promise, as `send`'s already was.
2. **The paging rules are observable**: a consumer can come to rely on how many requests a listing makes or on how a missing total count is read.
3. **The plugin module needs an SDK release that has the packages**, where before it needed only `send`.

### Mitigations

- The functions take what `send` takes plus the envelope key and an optional limit, so there is little in them that could need to change shape.
- The documentation of the paging function promises only which items are returned, not how they are fetched.
- The SDK and the plugin module are released together at one version from this repository, so the plugin module never names an SDK version that lacks the packages.

## References

- [ADR-026](./adr-026-typed-redmine-sdk.md) — the SDK this ADR refines.
- [ADR-017](./adr-017-redmine-plugin-sdk-module.md) — the plugin module and its copy of the decoding helper.
- [ADR-030](./adr-030-additional-tags-issue-tags.md) — the copy of the paging helper.
- [ADR-007](./adr-007-error-handling.md) and [ADR-023](./adr-023-design-evolution-from-adr-007.md) — the error type an unreadable answer is reported as.
