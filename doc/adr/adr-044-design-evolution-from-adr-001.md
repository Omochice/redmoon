# ADR-044: Design Evolution from ADR-001

## Status

Accepted

## Context

[ADR-001](./adr-001-five-module-moonbit-workspace.md) keeps every SDK as its own module in this repository, joined by `moon.work`, so that each can be published alone while a change across an SDK and the application stays one commit.

In practice the modules were released together with the application.
release-please kept one version for the whole repository and wrote it into every module manifest, so `omochice/schema`, `omochice/mcp`, and `omochice/keyring` carried the version of redmoon whether or not they had changed.

`schema`, `mcp`, and `keyring` know nothing of Redmine.
They now live in the [moonmoon](https://github.com/Omochice/moonmoon) repository, which versions and releases each module on its own, and they are published to mooncakes as `Omochice/schema`, `Omochice/mcp`, and `Omochice/keyring`.
Their sources there are the same as the ones this repository held.

This ADR records how redmoon depends on them from now on; every other decision of ADR-001 still holds as written.

## Design Changes from ADR-001

### 1. `schema`, `mcp`, and `keyring` are dependencies, not workspace members

#### Original Design (ADR-001)

Five modules, `schema`, `mcp`, `redmine`, `keyring`, and `redmoon`, live in this repository and are listed in `moon.work`.

#### Revised Design

`schema`, `mcp`, and `keyring` are removed from this repository and from `moon.work`.
redmoon and the integration tests import the published modules from mooncakes.
`redmine`, `redmine-plugins`, and `redmoon` stay in the workspace as before.

#### Rationale

The three modules change for reasons of their own, and none of those reasons is Redmine, so a separate repository gives each its own version and release, which ADR-001 aimed for and the shared release did not deliver.
`redmine` and `redmine-plugins` stay because they change together with the tools that expose them, which is the case the workspace was chosen for.

### 2. Their versions are pinned by hand, apart from the redmoon release

#### Original Design (ADR-001)

A member imports a sibling at the version the workspace releases together.

#### Revised Design

redmoon names an exact published version of each of the three modules, and the redmoon release no longer rewrites it.

#### Rationale

A version that follows redmoon would name a release that does not exist, since the three modules are released from another repository on their own schedule.

### 3. The module names keep the owner's capitalization

#### Original Design (ADR-001, Decision 2)

The modules share the `omochice/` prefix.

#### Revised Design

The three modules are named `Omochice/schema`, `Omochice/mcp`, and `Omochice/keyring`, as published.
The modules that stay here keep the `omochice/` prefix.

#### Rationale

A dependency is named exactly as the registry publishes it, and ADR-001's reason for having no project prefix still holds for both spellings.

### Not Decided Here

Whether `redmine` and `redmine-plugins` also move out is left open until they are needed outside redmoon.

## Consequences

### Positive

1. **Each library is released when it changes**, instead of with every redmoon release.
2. **This repository holds only what is about Redmine**, so its CI and release cover only redmoon and its Redmine SDKs.

### Negative

1. **A change that needs a new feature in one of the three modules takes two releases**: one in moonmoon, then a version bump here.
2. **The round trip through the OS credential store is no longer tested here**, so a redmoon build could pick up a broken `keyring` release.
3. **Module names use two spellings of the owner**: `Omochice/` for the dependencies and `omochice/` for the modules that stay.

### Mitigations

- redmoon pins exact versions, so a moonmoon release never changes a redmoon build until the version is raised here, and the raise runs through this repository's CI.
- moonmoon runs the credential store round trip on macOS for every change to `keyring`, before a release is published.
- The spelling is fixed by the published names, so a wrong one fails to resolve when the module is built rather than at run time.

## References

- [ADR-001](./adr-001-five-module-moonbit-workspace.md) — the decision this ADR refines.
- [moonmoon](https://github.com/Omochice/moonmoon) — the repository the three modules moved to.
