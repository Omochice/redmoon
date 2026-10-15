# ADR-014: Design Evolution from ADR-010

## Status

Proposed

## Context

[ADR-010](./adr-010-release-distribution.md) decided that release-please versions redmoon, bumping the version in `redmoon/moon.mod` and in a version constant marked `x-release-please-version`.
Writing the release configuration found that release-please cannot bump `moon.mod`.
This ADR records how the version is bumped instead, so that ADR-010 is not followed into a configuration that never updates the manifest.

## Design Changes from ADR-010

### 1. release-please bumps only the version constant

**Original Design (ADR-010)**: release-please bumps the version in `redmoon/moon.mod` and in `redmoon/src/build/version.mbt`.

**Revised Design**: release-please bumps only `redmoon/src/build/version.mbt`; the `version` in `redmoon/moon.mod` is bumped by hand in the release pull request.

```json
"extra-files": ["redmoon/src/build/version.mbt"]
```

**Rationale**: release-please's generic updater needs the `x-release-please-version` marker on the same line as the version, and `moonfmt` moves a trailing comment in `moon.mod` onto its own line, so the marker can never stay where the updater looks.
The version reported by `redmoon --version` and `redmoon_info` comes from `version.mbt`, so that is the file that must not lag.

## Consequences

### Positive

1. **The reported version always follows the release**, since release-please owns the constant the binary prints.

### Negative

1. **`moon.mod`'s version can lag** the released version if the hand bump is forgotten, which matters once the module is published to mooncakes.

### Mitigations

- A CI check that compares the version in `moon.mod` with the one in `version.mbt` catches a forgotten bump; it is a follow-up.

## References

- [ADR-010](./adr-010-release-distribution.md) — the decision this ADR refines.
