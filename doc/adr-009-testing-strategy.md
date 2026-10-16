# ADR-009: Unit Tests on Fakes, Integration Tests against a Throwaway Redmine

## Status

Proposed (refined by [ADR-013](./adr-013-design-evolution-from-adr-009.md))

## Context

redmoon crosses three boundaries that are awkward in CI: the Redmine HTTP API, the OS credential store, and the local filesystem.
denomine-mcp put each behind a port with a fake for unit tests, and ran its Redmine client against a throwaway Redmine from `compose.yaml` only when `DENOMINE_TEST_ENDPOINT` and `DENOMINE_TEST_API_KEY` were set (its ADR-0007).
Its CI starts that Redmine, enables the REST API with `rails runner`, loads the default data, creates a project, and passes the key to the tests through the environment.

redmoon reads its API key only from the OS keyring ([ADR-008](./adr-008-keyring-module-and-credential-cli.md)), and a CI runner has no keyring to log in to.

## Decision

We will test each module on fakes, and test the Redmine SDK and the assembled server against a real Redmine when one is configured.

### 1. Ports are traits, and fakes live next to them

redmoon's tools depend on traits for the Redmine operations, the credential store, and the filesystem, and each trait has a fake in the same package.

**Rationale**: handlers, schemas, and CLI logic then run in `moon test` on every platform with no network, store, or files.

### 2. The Redmine SDK has integration tests gated by the environment

They run when `REDMOON_TEST_ENDPOINT` and `REDMOON_TEST_API_KEY` are set, and are skipped otherwise.
`compose.yaml` and the CI seeding steps are taken from denomine-mcp.

**Rationale**: request encoding and response decoding are what a fake cannot check, and running them against the same Redmine version as denomine-mcp's tests compares like with like.

### 3. The server is exercised in process with the real SDK

An integration test builds the MCP server with the real Redmine client and a fake keyring holding the test key, sends JSON-RPC lines in, and checks the lines that come out.

**Rationale**: this covers the whole path from a `tools/call` line to Redmine and back without adding a way to pass the key outside the keyring, which the product deliberately lacks.

### 4. The keyring module is tested against the real store where one exists

On macOS and Windows the tests write, read, list, and delete an entry under a test service name; on Linux they run only when a Secret Service is available.

**Rationale**: the C stubs are the part most likely to break, and only a real store exercises them.

## Consequences

### Positive

1. **Fast tests everywhere**: most tests need nothing but the compiler.
2. **Real wiring is tested**: the SDK against Redmine, the server end to end, the stubs against the OS.
3. **No test-only credential path** in the shipped binary.

### Negative

1. **The compiled binary's own `serve` start-up is not exercised in CI**, since it reads the keyring.
2. **Integration tests are skipped locally** unless the developer starts Redmine and sets the variables.
3. **Keyring tests touch the developer's real store** on macOS and Windows.

### Mitigations

- `serve` is a thin composition of tested parts: the keyring lookup, the endpoint canonicalization, and the server.
- `docs/verification.md` gives the commands to start Redmine and export the variables, as denomine-mcp's does.
- The keyring tests use a dedicated service name and delete their entries even on failure.

## References

- [denomine-mcp ci.yaml](https://github.com/Omochice/denomine-mcp/blob/main/.github/workflows/ci.yaml)
- [ADR-006](./adr-006-typed-redmine-sdk.md) — the SDK under integration test.
- [ADR-008](./adr-008-keyring-module-and-credential-cli.md) — the store the server reads.
