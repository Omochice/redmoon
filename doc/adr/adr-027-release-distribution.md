# ADR-027: Release with release-please, One Shared Version, and Binaries Built as the Flake Package

## Status

Accepted

## Context

This ADR consolidates the release and distribution decisions that were spread over [ADR-010](./adr-010-release-distribution.md), [ADR-014](./adr-014-design-evolution-from-adr-010.md), [ADR-020](./adr-020-design-evolution-from-adr-010.md), and [ADR-022](./adr-022-design-evolution-from-adr-014.md).
ADR-010 set the release flow, and the three later ADRs each refined part of it, so a reader had to read four files in order to learn the release design as it stands.
This ADR restates the decision with every refinement folded in and replaces the four as the primary record.

An MCP client starts redmoon as a local process, so a user needs one executable per platform and no runtime ([ADR-002](./adr-002-native-backend-and-target-platforms.md)).
MoonBit does not cross-compile, so every asset is built on a runner of its own OS and architecture.
The development toolchain comes from moonbit-overlay, which does not publish MoonBit for every target platform.

The repository holds several MoonBit modules ([ADR-001](./adr-001-five-module-moonbit-workspace.md)).
Each has a `moon.mod`, which is the unit published to mooncakes and carries the version consumers see.
The root `moon.work` lists `omochice/keyring`, `omochice/mcp`, `omochice/redmine`, `omochice/redmine-plugins`, `omochice/redmoon`, and `omochice/schema`; `omochice/integration-test` has a `moon.work` of its own that builds against the same siblings.

`redmoon_info` reports the version a binary was released as, the commit it was built from, and whether the tree was dirty ([ADR-028](./adr-028-tool-surface.md)).
A single executable has no data files beside it to read, so both values have to be compiled in.

## Decision Drivers

The drivers below decided between the options that follow.

- **No hand-kept version**: every place that names the release version is updated by the release tool.
- **One build path**: the binary attached to a release is the binary the Nix package produces.
- **Every supported platform built before a tag exists**: a broken platform shows up on a pull request, not at release time.
- **One release package**: the release configuration and workflow stay as small as one version allows.

## Considered Options

The options below were weighed for where the version lives, how modules are versioned, and how assets are built.

### Option 1: An inline `x-release-please-version` marker in `moon.mod` and in a MoonBit constant

**Pros:**

- No extra file; the version sits where MoonBit and readers expect it.

**Cons:**

- The inline marker has to share a line with the version, and `moonfmt` moves a trailing comment onto a line of its own, in `moon.mod` and in MoonBit source alike, after which release-please no longer updates it.

### Option 2: The version in a JSON file only, with `moon.mod` bumped by hand

**Pros:**

- release-please updates a JSON value by path without any marker, so formatting cannot break it.

**Cons:**

- The hand bump was forgotten, and `moon.mod` lagged the release by several versions.

### Option 3: A release-please package per module

**Pros:**

- A module's version would rise only when that module changes.

**Cons:**

- The root package `.` would still receive every commit.
- The generic markers cannot name another package's version, so the `omochice/*` imports would need `moon work sync` on the release pull request branch, which release-please force-pushes on every update.
- `releases_created` in `release.yaml` would turn true for a release of any SDK and start a binary build.

### Option 4: Each release job runs `moon build --target native --release`

**Pros:**

- Works on any runner that has the MoonBit installer, including those without Nix.

**Cons:**

- The release assets and the Nix package would come from two build paths that can drift apart.

### Option 5: One shared version bumped through block markers and a JSON file, with assets built as the flake package (chosen)

**Pros:**

- The block form, `x-release-please-start-version` and `x-release-please-end` each on its own line, survives `moonfmt`, so nothing is bumped by hand.
- The asset is the Nix package.

**Cons:**

- Only platforms with a moonbit-overlay toolchain can build an asset this way (Decision section 6).

## Decision

We will release redmoon with release-please as one package whose version every module shares, and build each asset as the flake package on a runner of its own platform.

### 1. release-please owns the release

`.github/release-please-config.json` defines a single root package `.` with `release-type: simple`, and `.github/release-please-manifest.json` records its version.
Tags are `vX.Y.Z` without a component name.
`release.yaml` runs release-please on every push to `main`; it opens the release pull request from Conventional Commits, and merging that pull request creates the tag and a draft GitHub release.
`releases_created` gates the build and publish jobs, so a push that releases nothing builds nothing there.

**Rationale**: the commit history is already in Conventional Commits, and one tool both versions and tags.

### 2. Every module carries the release version

The root package lists `redmoon/src/build/version.json` as a `json` extra file updated at `$.version`, and every module's `moon.mod` as a `generic` extra file.
Each `moon.mod` wraps its `version` in a marker block, and wraps its `omochice/*` imports in a second block so they move with the version; [`redmoon/moon.mod`](../../redmoon/moon.mod) shows both.
Third-party imports such as `moonbitlang/async` stay outside the blocks, and release-please leaves them untouched.
A new module needs both blocks and its own extra-file entry, alongside its `moon.work` entry; without them it stays at its first version.

**Rationale**: the block form avoids the failures of Options 1 and 2.
One shared version avoids every cost of a package per module listed under Option 3.
A module's version therefore says when it was released, not whether it changed.

### 3. The binary embeds `version.json`

The `redmoon/src/build` package embeds `version.json` with a rule built into `moon`, and parses it once when the program starts.
Its [`moon.pkg`](../../redmoon/src/build/moon.pkg) declares a `rule` that runs `:embed` and a `dev_build` that applies it to `version.json`, producing `version_json.mbt`.
The generated `version_json.mbt` is ignored by git; `moon check`, `moon test`, and `moon build` regenerate it.
A test reads the embedded file and compares it with the parsed version, so a malformed `version.json` fails CI instead of stopping a released binary at start-up.
`version.json` stays next to the `moon.mod` versions because the embedding does not read `moon.mod`.

**Rationale**: release-please updates a JSON value by path without any marker, and `:embed` needs no shell, so the rule behaves the same on every runner.
MoonBit's documentation asks for generated files to be committed because `dev_build` does not run for a package used as a dependency from the registry.
`omochice/redmoon` is not consumed that way: `omochice/integration-test` builds it from the local tree through its `moon.work`.
Regenerating the file on every build removes any chance of it lagging the JSON in a release pull request.

### 4. Build information is stamped before the build

`redmoon/src/build/info.mbt` is committed with `build` set to `None`, so a build from source reports `build: null`.
Before every build in `build.yaml`, `task build-info:stamp` overwrites it with the checkout's commit and dirty flag.
The `check` job in `ci.yaml` runs `task build-info:verify`, which fails unless the committed file is in its `None` form.

**Rationale**: the information has to be compiled in, and a generated source file needs no lookup at run time.

### 5. Each asset is the flake package built on its own runner

`.github/workflows/build.yaml` runs one job per asset.
Each job stamps the build information, runs `task build`, which is `nix build .#redmoon --out-link _build/redmoon`, copies `_build/redmoon/bin/redmoon` to `dist/redmoon-<target>`, smoke-runs it with `--help`, and uploads it as a workflow artifact.
The flake package is built with moon-nix from the locked mooncakes index, and the stamped `info.mbt` reaches it because the file is tracked by git.
The package strips the binary and forbids references to the toolchain and the build tree, so its closure is the binary alone.
`ci.yaml` calls the same workflow on every pull request and every push to `main`, without attaching anything to a release.

**Rationale**: one build path means the asset attached to a release is the binary `nix build github:Omochice/redmoon` produces, and the smoke run of the asset also covers the Nix package.
Building on pull requests surfaces a broken platform before a tag exists.

### 6. Only aarch64-darwin and x86_64-linux are built for now

moonbit-overlay publishes MoonBit only for these two platforms, so they are the only ones the flake package of section 5 can build.
ADR-002 also lists `aarch64-unknown-linux-gnu` and `x86_64-pc-windows-msvc` among the target platforms, but neither has a release asset or a CI job at the moment.
When those two return, each needs a job that runs `moon build --target native --release` with the official installer beside the Nix jobs, and the asset path then differs from section 5.

**Rationale**: the single build path of section 5 was chosen knowing that it leaves these two platforms out; dropping them for good has not been decided.

### 7. The publish job attaches the assets and publishes the draft

After the build, `release.yaml` downloads every artifact, writes `SHA256SUMS` over them, attaches all of them to the draft release created in section 1, and then marks the release as not a draft.
The release-please and publish jobs act through a GitHub App token issued in the `release` environment.
A release therefore becomes public only with every asset and the checksum file attached.

### 8. Publishing to mooncakes is manual, and a module with its own version moves out

Publishing a module to mooncakes is a manual `moon publish` from its directory, and only a module that changed since its last publication is published.
When a module needs to be versioned apart from redmoon, for example because it gains users outside this repository or a release cadence of its own, it moves to a repository of its own instead of receiving its own release-please package here.
`git subtree split` carries its history over; the `vX.Y.Z` tags of its earlier versions stay in this repository, and the new repository starts tags of its own.

**Rationale**: the wish for a separate version and the wish for a separate repository arise from the same cause, so one rule covers both and this repository keeps one release package.
mooncakes resolves a module by name, and an import names no repository, so a move changes nothing for consumers beyond the `repository` field of later versions.
A module that did not change can be left unpublished, so a gap between its published versions does no harm to a consumer.

## Consequences

### Positive

The decision meets all four Decision Drivers, which are the positive consequences and are not repeated here.

### Negative

The costs below are accepted with the decision.

1. **A module's version rises without a change to it**.
2. **Only the platforms of Decision section 6 get a binary**: Linux arm64, Windows, and Intel macOS users have none.
3. **The build depends on the moon-nix fork branch** `Omochice/moon-nix/fix-moon-compat` until its fixes land upstream.
4. **SDK modules are not published automatically**.
5. **A module that moves out leaves `moon.work`**, and a change across it and redmoon then needs the module to be published before redmoon can import the new version.
6. **`info.mbt` is overwritten in CI**, and a stamped copy committed by mistake would report a stale commit from every build; the check of Decision section 4 rejects such a commit.

### Mitigations

The measures below keep those costs small.

- A module is published to mooncakes only when it changed, so every version a consumer can install carries a change.
- The README lists only the two platforms that have binaries.
- The fork branch is pinned in `flake.lock`, so a release changes only when the lock is updated.
- A module is moved out only once its API changes rarely, which keeps publish-first changes infrequent.

## References

- [ADR-010](./adr-010-release-distribution.md), [ADR-014](./adr-014-design-evolution-from-adr-010.md), [ADR-020](./adr-020-design-evolution-from-adr-010.md), and [ADR-022](./adr-022-design-evolution-from-adr-014.md) — the records this ADR consolidates and supersedes.
- [ADR-001](./adr-001-five-module-moonbit-workspace.md) — why the modules share one repository.
- [ADR-002](./adr-002-native-backend-and-target-platforms.md) — the native backend and the target platforms.
- [ADR-028](./adr-028-tool-surface.md) — `redmoon_info`.
- [release-please generic updater](https://github.com/googleapis/release-please/blob/main/docs/customizing.md#updating-arbitrary-files) — the block markers.
- [MoonBit package configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html) — `rule` and `dev_build`.
- [moon-nix](https://github.com/moonbit-community/moon-nix) — the builder behind the flake package.
