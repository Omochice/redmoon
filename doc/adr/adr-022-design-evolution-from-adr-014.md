# ADR-022: Design Evolution from ADR-014

## Status

Proposed

## Context

[ADR-014](./adr-014-design-evolution-from-adr-010.md) moved the release version into `redmoon/src/build/version.json` and left the `version` in each `moon.mod` to be bumped by hand, because release-please's inline marker has to share a line with the version and `moonfmt` moves a trailing comment onto a line of its own.
The hand bump was forgotten in practice: redmoon was released as `v0.3.0` while every `moon.mod` still read `0.1.0`.
That lag matters once the SDK modules are published to mooncakes, where the version in `moon.mod` is the version consumers see.

release-please's generic updater also accepts a block form, `x-release-please-start-version` and `x-release-please-end`, each on its own line, and rewrites every version between them.
With moon 0.1.20261023, `moonfmt` keeps both comments; it inserts a blank line after the opening one and leaves the file unchanged on a second run.
The generic updater of release-please 17.11.2 applied to such a `moon.mod` rewrote the module version and the imports inside the block, and left `moonbitlang/async@0.22.5` outside it untouched.

Giving each module its own version was weighed against giving them all one.
This ADR records what was chosen, so that ADR-014's hand bump is not followed after it stopped being needed.

## Design Changes from ADR-014

### 1. release-please bumps every `moon.mod`

**Original Design (ADR-014)**: release-please updates `version.json` only, and the `version` in `redmoon/moon.mod` is bumped by hand.

**Revised Design**: every module's `moon.mod` carries the block markers, and the root package of `.github/release-please-config.json` lists each one as a `generic` extra file next to `version.json`.

```text
// x-release-please-start-version

version = "0.3.0"
// x-release-please-end
```

`version.json` stays, because the binary embeds it and the embedding does not read `moon.mod`.

**Rationale**: the block form avoids the same-line requirement that ADR-014 ran into, so the hand bump and the CI check that ADR-014 planned against a forgotten bump are both unnecessary.

### 2. All modules share one version

**Revised Design**: `omochice/schema`, `omochice/mcp`, `omochice/redmine`, `omochice/redmine-plugins`, `omochice/keyring`, `omochice/redmoon`, and `omochice/integration-test` all carry the redmoon release version.
The `omochice/*` imports in each `moon.mod` sit inside a marker block too, so they move with the version.
The versions were first aligned to `0.3.0`, the last release.

```text
import {
  "moonbitlang/async@0.22.5",
  // x-release-please-start-version
  "omochice/schema@0.3.0",
  // x-release-please-end
}
```

**Rationale**: a version per module within this repository would need a release-please package per module, and the root package `.` would still receive every commit.
The generic markers cannot name another package's version, so the imports would need `moon work sync` run on the release pull request branch, which release-please force-pushes on every update.
`releases_created` in `release.yaml` would also turn true for a release of any SDK and start a binary build.
One version needs none of this.
Publishing to mooncakes stays manual ([ADR-010](./adr-010-release-distribution.md)), so a module that did not change can be left unpublished, and a gap between its published versions does no harm to a consumer.

### 3. A module that needs its own version moves to its own repository

**Revised Design**: when a module needs to be versioned apart from redmoon, for example because it gains users outside this repository or a release cadence of its own, it is moved to a repository of its own instead of being given its own release-please package here.

**Rationale**: the wish for a separate version and the wish for a separate repository arise from the same cause, so one rule covers both and this repository keeps a single release package.
mooncakes resolves a module by its name, and an import names no repository, so a move changes nothing for consumers beyond the `repository` field of later versions.
`git subtree split` carries the module's history over; the `vX.Y.Z` tags that marked its earlier versions stay in this repository, and the new repository starts tags of its own.

## Consequences

### Positive

1. **No version to bump by hand**, so `moon.mod` cannot lag the release.
2. **One release package**, so the release configuration and workflow stay as they are.

### Negative

1. **A module's version rises without a change to it**, so the version says when it was released, not whether it changed.
2. **A module that moves out leaves `moon.work`**, and a change across it and redmoon then needs the module to be published before redmoon can import the new version.
3. **Every module needs the markers**, and a new module without them stays at its first version.

### Mitigations

- A module is published to mooncakes only when it changed, so every version a consumer can install carries a change.
- A module is moved out only once its API changes rarely, which keeps publish-first changes infrequent.
- The markers and the extra-file entry are part of adding a module, alongside the `moon.work` entry.

## References

- [ADR-014](./adr-014-design-evolution-from-adr-010.md) — the decision this ADR refines.
- [ADR-001](./adr-001-five-module-moonbit-workspace.md) — why the modules share one repository.
- [ADR-010](./adr-010-release-distribution.md) — release-please and manual publishing.
- [release-please generic updater](https://github.com/googleapis/release-please/blob/main/docs/customizing.md#updating-arbitrary-files) — the block markers.
