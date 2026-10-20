# ADR-018: Design Evolution from ADR-009

## Status

Proposed

## Context

[ADR-009](./adr-009-testing-strategy.md) decided that the Redmine SDK and the assembled server are tested against a real Redmine when `REDMOON_TEST_ENDPOINT` and `REDMOON_TEST_API_KEY` are set, and are skipped otherwise.
The tests were written next to the code they exercise, each returning early when either variable was unset.
MoonBit has no way to skip a test at run time, so a test that returns early is reported as passed, and a plain `moon test` counted 35 tests that never reached Redmine.
Those tests were told apart only by a `live:` prefix on their names, a convention that no document recorded.

`moon test` can select tests by a name pattern with `-f`, but cannot leave out the tests that match one, so the prefix could not keep them out of a plain run either.
The `#skip` attribute keeps a test out of every run except one with `--include-skipped`, which also runs the documentation examples that are marked `#skip` because they point at `https://redmine.example.com` and cannot pass.

## Design Changes from ADR-009

### 1. The integration tests live in their own module

**Original Design (ADR-009)**: the SDK's integration tests run when the variables are set and are skipped otherwise, and the server is exercised in process from its own package.

**Revised Design**: every test that needs a real Redmine lives in `integration-test/`, a module named `omochice/integration-test` that the root `moon.work` does not list.
The module has its own `moon.work`, which lists itself and every root member, so `task test:integration` runs `moon test` there and covers the unit tests together with the integration tests.
Its shared helper fails the test, naming the missing variable, when either variable is unset.
The `live:` prefix is dropped, because the module already says that its tests need Redmine.

**Rationale**: a module the root workspace does not list is never compiled by a plain `moon test`, so its tests can fail on a missing variable without turning a run on a machine without Redmine red.
A failure cannot be mistaken for a pass, which an early return could.
Living in another module also limits the tests to the public API that a consumer sees, which the compiler enforces.

### 2. The coverage report is written from the repository root

**Revised Design**: `task test:integration:coverage` runs the tests in `integration-test/` and then writes the Cobertura report from the repository root.

**Rationale**: `moon coverage report` names a file relative to the directory it runs in and falls back to an absolute path for a file outside it, so a report written inside the module would name every file of the other modules by absolute path and break octocov's comparison with earlier runs.

## Consequences

### Positive

1. **A skipped integration test cannot pass**: a missing variable fails it.
2. **A plain `moon test` reports only the tests it ran**.
3. **The integration tests use only the public API**, so they exercise what a consumer can call.
4. **One helper replaces the copies** that `omochice/redmine` and `omochice/redmine-plugins` each kept in `internal/livetest` ([ADR-017](./adr-017-redmine-plugin-sdk-module.md)).

### Negative

1. **The tests sit away from the code they exercise**, so a change to the SDK has a second place to look.
2. **Internal packages cannot be tested against Redmine directly**: the paging test now goes through `@issues.list`, which sends the same request as the internal pager.
3. **The module's `moon.mod` repeats the dependency versions** of the root members, such as `moonbitlang/async`, and has to be updated with them.
4. **A `_build/` from before this change** keeps coverage traces of the deleted `internal/livetest` packages, and `moon coverage report` fails on them until that directory is removed.

### Mitigations

- `task check` type-checks the module as well, so a change to a public API that breaks an integration test fails the check job, not only the integration job.
- The paging arithmetic stays covered by the fake in `redmine/src/internal/paging/paging_wbtest.mbt`; the integration test only confirms that Redmine honours `limit` and `offset`.
- CI starts from a fresh checkout, so the stale traces affect only local `_build/` directories.

## References

- [ADR-009](./adr-009-testing-strategy.md) — the decision this ADR refines.
- [ADR-017](./adr-017-redmine-plugin-sdk-module.md) — the plugin SDK module whose `internal/livetest` this ADR removes.
- [verification.md](./verification.md) — how to run the integration tests.
