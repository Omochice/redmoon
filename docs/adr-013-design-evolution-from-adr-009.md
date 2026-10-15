# ADR-013: Design Evolution from ADR-009

## Status

Proposed

## Context

[ADR-009](./adr-009-testing-strategy.md) decided that the tools depend on ports with fakes, that the Redmine SDK and the assembled server have integration tests gated by the environment, and that the keyring module is tested against the real store.
Its decision 1 placed each fake next to its trait.
Writing the tools placed the fakes elsewhere, and this ADR records where and why.

## Design Changes from ADR-009

### 1. Fakes live in the white-box test files of the package

**Original Design (ADR-009)**: each trait has a fake in the same package, next to the trait.

**Revised Design**: each fake is defined in the white-box test file of the tool that uses it, for example `FakeIssues` in `redmoon/src/tools/issues_wbtest.mbt` and the fake credential store in `redmoon/src/cli/commands_wbtest.mbt`.
The traits and their `@redmine.Redmine` implementations stay in `<group>_port.mbt`.

**Rationale**: a fake in a source file is compiled into the library and the shipped binary, and is part of the package's public surface if it is `pub`; a `*_wbtest.mbt` file is compiled only for tests and still sees the package's private items.
Each fake is used by one tool's tests, so nothing is shared that would justify a separate test-support package.

## Consequences

### Positive

1. **No test code in the binary or the package interface**.
2. **Each tool's tests are self-contained** in one file.

### Negative

1. **Fakes are not reusable** from another package's tests.

### Mitigations

- The CLI tests that need the tools use the real tools over an in-memory pipe with a fake credential store, so no other package has needed a tool's fake so far; a shared test package can be added when one does.

## References

- [ADR-009](./adr-009-testing-strategy.md) — the decision this ADR refines.
