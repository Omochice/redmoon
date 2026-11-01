# ADR-014: Design Evolution from ADR-010

## Status

Proposed (refined by [ADR-022](./adr-022-design-evolution-from-adr-014.md))

## Context

[ADR-010](./adr-010-release-distribution.md) decided that release-please versions redmoon, bumping the version in `redmoon/moon.mod` and in a version constant marked `x-release-please-version`.
Writing the release configuration found that release-please cannot keep either reliably: its generic updater needs the marker on the same line as the version, and `moonfmt` moves a trailing comment onto its own line, both in `moon.mod` and in MoonBit source.
This ADR records where the version lives instead, so that ADR-010 is not followed into a configuration that never updates it.

## Design Changes from ADR-010

### 1. The release version lives in a JSON file that the build embeds

**Original Design (ADR-010)**: release-please bumps the version in `redmoon/moon.mod` and in a MoonBit constant marked `x-release-please-version`.

**Revised Design**: the version lives in `redmoon/src/build/version.json`, which release-please updates by JSON path; the build package embeds it with a `dev_build` rule and reads it once at start-up.

```json
{ "type": "json", "path": "redmoon/src/build/version.json", "jsonpath": "$.version" }
```

```text
rule(name: "embed", command: ":embed -i $input -o $output --name version_json")

dev_build(rule: "embed", input: "version.json", output: "version_json.mbt")
```

The generated `version_json.mbt` is not committed; `moon check`, `moon test`, and `moon build` regenerate it.
The `version` in `redmoon/moon.mod` is bumped by hand.

**Rationale**: release-please updates a JSON value by path without any marker, so `moonfmt` cannot break it, and `:embed` is built into `moon`, so the rule behaves the same on every runner including Windows.
MoonBit's documentation asks for generated files to be committed because `dev_build` does not run for a package used as a dependency; the application has no dependents, so regenerating the file on every build removes any chance of it lagging the JSON in a release pull request.

## Consequences

### Positive

1. **The reported version always follows the release**, since release-please owns the file the binary embeds.
2. **No generated file to keep in sync** in a release pull request.

### Negative

1. **`moon.mod`'s version can lag** the released version if the hand bump is forgotten, which matters once the module is published to mooncakes.
2. **A malformed `version.json` stops the binary at start-up**.

### Mitigations

- A CI check that compares the version in `moon.mod` with the one in `version.json` catches a forgotten bump; it is a follow-up.
- A test reads the embedded file, so a malformed `version.json` fails CI before it can be released.

## References

- [ADR-010](./adr-010-release-distribution.md) — the decision this ADR refines.
- [MoonBit package configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html) — `rule` and `dev_build`.
