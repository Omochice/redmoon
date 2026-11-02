# ADR-029: Unit Tests on Fakes in White-Box Files, Integration Tests in a Separate Module against a Throwaway Redmine

## Status

Accepted

## Context

This ADR consolidates [ADR-009](./adr-009-testing-strategy.md), [ADR-013](./adr-013-design-evolution-from-adr-009.md), and [ADR-018](./adr-018-design-evolution-from-adr-009.md) into one record of how redmoon is tested, and supersedes all three.
It also takes over the live-test helpers that [ADR-017](./adr-017-redmine-plugin-sdk-module.md) placed in `internal/livetest` of `omochice/redmine` and `omochice/redmine-plugins`.

redmoon crosses three boundaries that are awkward in CI: the Redmine HTTP API, the OS credential store, and the local filesystem.
The pattern of putting each boundary behind a port with a fake, and of running the Redmine client against a throwaway Redmine from `compose.yaml` only when one is configured, comes from denomine-mcp.

redmoon reads its API key only from the OS keyring ([ADR-008](./adr-008-keyring-module-and-credential-cli.md)), and a CI runner has no keyring to log in to.
The shipped binary deliberately offers no other way to pass the key.

MoonBit has no way to skip a test at run time, so a test that returns early is reported as passed.
`moon test` can select tests by a name pattern with `-f`, but cannot leave out the tests that match one.
The `#skip` attribute keeps a test out of every run except one with `--include-skipped`, and that flag also runs every documentation example marked `#skip`, including those that point at `https://redmine.example.com` and cannot pass and those that would write to the user's credential store.

A module cannot import another module's `internal/` packages ([ADR-026](./adr-026-typed-redmine-sdk.md)), so a test that lives outside a module sees only that module's public API.

## Decision

We will test each package on fakes defined in its white-box test files, and test the Redmine SDK, the plugin SDK, and the assembled server against a real, throwaway Redmine from a separate workspace module that a plain `moon test` never compiles.

### 1. Ports are traits, and fakes live in the white-box test files of the package

redmoon's tools and CLI depend on `pub(open)` traits for the Redmine operations, the filesystem, and the credential store.
Each fake is defined in a `*_wbtest.mbt` file of the package that uses it, for example the fake of the credential store in `redmoon/src/cli/commands_wbtest.mbt`.
A fake needed by several tests of one package is defined once in one of those files and used by the others.

**Rationale**: handlers, schemas, and CLI logic then run in `moon test` on every platform with no network, store, or files.
A fake in a source file next to its trait was rejected because it is compiled into the library and the shipped binary, and is part of the package's public surface if it is `pub`.
A `*_wbtest.mbt` file is compiled only for tests, sees the package's private items, and is compiled together with the other test files of the same package.
A separate test-support package was rejected because no fake has been needed by the tests of another package.

### 2. Every test that needs a real Redmine lives in the `integration-test/` module

`integration-test/` is a module named `omochice/integration-test` that the root `moon.work` does not list.
It has its own `moon.work`, which lists itself and every root member, so running `moon test` there covers the unit tests together with the integration tests.
Its packages are `src/sdk` for `omochice/redmine`, `src/plugins` for `omochice/redmine-plugins`, and `src/server` for the assembled server, and they share one helper, `src/livetest`.
`@livetest.redmine()` builds a client from `REDMOON_TEST_ENDPOINT` and `REDMOON_TEST_API_KEY`, and fails the test, naming the missing variable, when either is unset.
Neither SDK module keeps a live-test helper of its own.

**Rationale**: a module the root workspace does not list is never compiled by a plain `moon test`, so its tests can fail on a missing variable without turning a run on a machine without Redmine red.
A failure cannot be mistaken for a pass, which a test that returns early when the variables are unset can.
Keeping the tests next to the code was rejected because, as Context describes, `-f` cannot exclude them from a plain run and `#skip` cannot be lifted for them alone.
Living in another module also limits the tests to the public API that a consumer sees, which the compiler enforces, and one helper serves both SDKs where each had kept a copy.

### 3. The server is exercised in process with the real SDK

A server integration test passes the client from `@livetest.redmine()` to `@cli.build_server`, the function `serve` uses to assemble the MCP server, writes an `initialize` line and a `tools/call` line into an in-memory pipe, and checks the lines that come out.
The unit tests in `redmoon/src/cli/serve_wbtest.mbt` drive the same exchange with a client whose key is a placeholder, so tool registration is checked without a network and a real `tools/call` is checked in the integration module.

**Rationale**: this covers the whole path from a `tools/call` line through schema validation to Redmine and back.
`build_server` takes a `@redmine.Redmine` rather than a credential store, so the test reaches it without a keyring and without adding a way to pass the key outside the keyring, which the product deliberately lacks.

### 4. The Redmine is a throwaway instance prepared by tasks

`compose.yaml` builds a Redmine with the redmine_issue_templates plugin, so that the plugin SDK can be tested too.
Tasks of [ADR-015](./adr-015-task-runner.md) start it, seed the projects and records the tests rely on, and run the integration tests against it, and [verification.md](../verification.md) gives the commands and describes what each seeding step creates and why.

**Rationale**: request encoding and response decoding are what a fake cannot check, so they are tested against a real Redmine.
Defining the preparation as tasks lets a developer run exactly what CI runs.

### 5. The coverage report is written from the repository root

`task test:integration:coverage` clears the coverage data at the root and in `integration-test/`, runs the integration tests with coverage, and then writes the Cobertura report from the repository root.
`octocov.yaml` excludes `integration-test/**`, so the report measures the root modules as exercised by both the unit tests and the integration tests.

**Rationale**: `moon coverage report` names a file relative to the directory it runs in and falls back to an absolute path for a file outside it, so a report written inside the module would name every file of the other modules by absolute path and break octocov's comparison with earlier runs.

### 6. The keyring module is tested against the real store only on request

The status mapping and the account-list parsing of `omochice/keyring` are plain unit tests.
The round trip that writes, reads, lists, and deletes an entry in the OS store runs only when `REDMOON_TEST_KEYRING=1` is set, which `task test:keyring` and `task test:keyring:coverage` do.
The round trip writes under a service name unique to the run and deletes its entry even when an assertion fails.

**Rationale**: the C stubs are the part most likely to break, and only a real store exercises them.
The store is shared with the user and with concurrent runs, so the round trip is opt-in and never touches an existing entry.

### 7. CI runs each kind of test in its own job

The `check` job runs the unit tests and `task check`, which type-checks `integration-test/` as well.
The `test-macos` job runs the unit tests and the keyring round trip.
The `integration` job prepares the Redmine and runs the integration tests with coverage, and the `report` job merges the two coverage reports for octocov.

**Rationale**: the store round trip runs on the macOS runner because a Keychain is available there.
Type-checking the integration module in `check` makes a public API change that breaks an integration test fail the check job, not only the integration job.

## Consequences

The decisions above trade the locality of the tests for a plain run that reports only what it ran.

### Positive

Most of the benefit comes from the split between a fast default run and a separate module for the slow tests.

1. **Fast tests everywhere**: most tests need nothing but the compiler.
2. **Real wiring is tested**: the SDKs against Redmine, the server end to end, the stubs against the OS.

### Negative

The costs fall mostly on where the tests live and on what a plain run leaves out.

1. **The compiled binary's own `serve` start-up is not exercised in CI**, since it reads the keyring.
2. **Integration tests need Docker and a seeded Redmine**, so they do not run locally unless the developer starts one.
3. **The integration tests sit away from the code they exercise**, so a change to an SDK has a second place to look.
4. **Internal packages cannot be tested against Redmine directly**: the paging test goes through `@issues.list`, which sends the same request as the internal pager.
5. **Fakes are not reusable** from another package's tests.
6. **`integration-test/moon.mod` repeats the version of `moonbitlang/async`** that the root members import, and has to be updated with them.
7. **The store round trip returns early in a plain `moon test`**, which reports it as passed, so a stub regression shows up only where the opt-in runs, and only the macOS job runs it.

### Mitigations

The following measures reduce those costs without moving the integration tests back next to the code.

- `serve` is a thin composition of tested parts: the keyring lookup, the endpoint canonicalization, and `build_server`.
- The paging arithmetic stays covered by the fake in `redmine/src/internal/paging/paging_wbtest.mbt`; the integration test only confirms that Redmine honours `limit` and `offset`.
- A shared test package can be added when the tests of another package need a fake.
- The versions of the `omochice/*` modules in `integration-test/moon.mod` are kept inside release-please markers, so only `moonbitlang/async` is updated by hand.

## References

The following records and files give the context this ADR relies on.

- [ADR-026](./adr-026-typed-redmine-sdk.md) — the SDK under integration test, and why another module sees only its public API.
- [ADR-008](./adr-008-keyring-module-and-credential-cli.md) — the store the server reads and the keyring module under test.
- [ADR-015](./adr-015-task-runner.md) — the tasks that prepare Redmine and run the tests.
- [ADR-017](./adr-017-redmine-plugin-sdk-module.md) — the plugin SDK module whose live-test helper this ADR replaces.
- [verification.md](../verification.md) — how to run the integration tests.
- [denomine-mcp ci.yaml](https://github.com/Omochice/denomine-mcp/blob/main/.github/workflows/ci.yaml) — the origin of the throwaway Redmine in CI.
