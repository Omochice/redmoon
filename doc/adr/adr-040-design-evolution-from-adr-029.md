# ADR-040: Design Evolution from ADR-029

## Status

Accepted

## Context

[ADR-029](./adr-029-testing-strategy.md) places every fake in a `*_wbtest.mbt` file of the package that uses it, and says nothing about the tests that need no fake.
Three habits grew in that silence: `schema/` has black-box `*_test.mbt` files only, `keyring/` splits its tests by whether they reach a private item, and `redmoon/src/cli` is white-box throughout, although `serve_wbtest.mbt`, `arguments_wbtest.mbt`, and `endpoint_wbtest.mbt` call only `build_server`, `parse_arguments`, and `canonicalize_endpoint`, which are public.
A reader could not tell from a file's suffix whether its tests depend on a private item.

ADR-029 also describes one live-test helper, `@livetest.redmine()`, reading two environment variables.
The Additional Tags work of [ADR-030](./adr-030-additional-tags-issue-tags.md) added `as_member()` and `as_tagger()`, which read `REDMOON_TEST_MEMBER_API_KEY` and `REDMOON_TEST_TAGGER_API_KEY`, because a dropped write, the administrator-only tag list, and the permission to create tags show only for a user who is not the administrator.
[verification.md](../verification.md) and `Taskfile.yaml` already name all four variables; ADR-029 §2 does not.

This ADR records both refinements so that ADR-029 is not read as the complete rule for where a test lives or as the complete list of what the integration tests read.

## Design Changes from ADR-029

### 1. A test file is black-box unless it needs a private item or a fake

#### Original Design (ADR-029)

Fakes live in `*_wbtest.mbt` files, and a fake needed by several tests of one package is defined once there.
Nothing is said about a test that needs no fake.

#### Revised Design

A test file is a black-box `*_test.mbt` file unless it needs a private item or a fake, which live in `*_wbtest.mbt`.
The three `redmoon/src/cli` files that reach only public functions become `serve_test.mbt`, `arguments_test.mbt`, and `endpoint_test.mbt`, and name the package as `@cli`.
`commands_wbtest.mbt` and `keyring_port_wbtest.mbt` stay white-box, since the first defines the fake store and the second tests a private mapping.

#### Rationale

A black-box test sees exactly what a consumer of the package sees, and the compiler enforces it, so a test that compiles as `*_test.mbt` proves that the behaviour is reachable through the public API.
Keeping every test white-box was rejected because it hides which tests would break if a private item changed and which would not.
Keeping the choice per package was rejected because three habits had already grown, and the suffix then said nothing.

### 2. The live-test helper provides three clients from four variables

#### Original Design (ADR-029)

`@livetest.redmine()` builds a client from `REDMOON_TEST_ENDPOINT` and `REDMOON_TEST_API_KEY`, and fails the test, naming the missing variable, when either is unset.

#### Revised Design

`src/livetest` provides three clients for the same `REDMOON_TEST_ENDPOINT`:

| Helper        | Variable                       | Acts as                                          |
| ------------- | ------------------------------ | ------------------------------------------------ |
| `redmine()`   | `REDMOON_TEST_API_KEY`         | the administrator                                |
| `as_member()` | `REDMOON_TEST_MEMBER_API_KEY`  | `redmoon-member`, who may not create tags        |
| `as_tagger()` | `REDMOON_TEST_TAGGER_API_KEY`  | `redmoon-tagger`, who may create tags as well    |

Each helper fails the test, naming the missing variable, when the endpoint or its own key is unset.
`task redmine:seed` writes the three keys under `_build/`, and `task test:integration` exports all four variables.

#### Rationale

Some behaviour never happens to an administrator, so a test of it needs a client with fewer permissions, and the difference between attaching an existing tag and creating a new one needs two such users.
A helper per role, each reading its own variable, keeps the rule of ADR-029 §2 that a missing variable fails the test by name instead of letting it pass.

## Consequences

The decisions above change where a test file goes and what the integration tests read, not how they run.

### Positive

1. **The suffix of a test file is informative**: `*_wbtest.mbt` now means that a private item or a fake is involved.
2. **ADR-029 §2 matches the task and the document**: a reader of the ADR learns every variable `task test:integration` exports.

### Negative

1. **A black-box file needs a `test` import list in `moon.pkg`** beside the `wbtest` one, and names every item of the package under test with `@cli.`.
2. **A seeded Redmine needs three users**, so the seed script is longer and a run against a hand-prepared instance needs two more keys.

## References

The following records and files give the context this ADR relies on.

- [ADR-029](./adr-029-testing-strategy.md) — the testing strategy this ADR refines.
- [ADR-030](./adr-030-additional-tags-issue-tags.md) — the plugin whose permissions introduced the member and tagger clients.
- [verification.md](../verification.md) — the tasks that seed the users and export the variables.
