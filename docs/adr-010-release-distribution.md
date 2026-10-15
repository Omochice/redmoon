# ADR-010: Release with release-please and per-Runner Native Builds

## Status

Proposed

## Context

denomine-mcp releases with release-please: merging the release pull request tags the version, and a workflow builds one binary per platform and attaches it to the GitHub release.
Its `denomine_mcp_info` tool reports the commit a binary was built from and whether the tree was dirty, read from a file the compile task writes and removes afterwards (its ADR-0016).

MoonBit does not cross-compile, so each asset is built on a runner of its own OS and architecture ([ADR-002](./adr-002-native-backend-and-target-platforms.md)).
A native build leaves the executable at `_build/native/release/build/<package path>/<name>.exe` on every OS.

## Decision

We will release redmoon the way denomine-mcp is released, with the build matrix of ADR-002.

### 1. release-please owns versions

release-please opens the release pull request from Conventional Commits and bumps the version in `redmoon/moon.mod` and in a version constant marked `x-release-please-version`.
Merging it creates the tag and the GitHub release.
Only `omochice/redmoon` is released this way at first.

**Rationale**: the commit history is already in Conventional Commits, and one tool both versions and tags; the SDK modules are published to mooncakes on their own schedule once they settle.

### 2. One job per asset

| Asset                                | Runner             |
| ------------------------------------ | ------------------ |
| `redmoon-aarch64-apple-darwin`       | `macos-15`         |
| `redmoon-x86_64-unknown-linux-gnu`   | `ubuntu-latest`    |
| `redmoon-aarch64-unknown-linux-gnu`  | `ubuntu-24.04-arm` |
| `redmoon-x86_64-pc-windows-msvc.exe` | `windows-latest`   |

Each job runs `moon build --target native --release` and uploads the renamed executable to the release.
The same matrix runs on pull requests without uploading.

**Rationale**: the asset names are denomine-mcp's, and building on pull requests surfaces a broken platform before a tag exists.

### 3. Build info is generated before the build

The workflow writes a MoonBit source file holding the commit and the dirty flag before building; the checked-in version of that file holds `None`, so a build from source reports `build: null`.

**Rationale**: MoonBit has no file embedding, so the information has to be compiled in, and a generated source file needs no runtime lookup.

## Consequences

### Positive

1. **Same release flow as denomine-mcp**.
2. **Every platform is built on every pull request**.

### Negative

1. **The SDK modules are not released automatically**.
2. **A generated source file** is overwritten in CI and must not be committed in that state.

### Mitigations

- Publishing an SDK is a manual `moon publish` from its directory until its API is stable.
- The workflow overwrites the file only in the CI checkout, and a check fails if the committed file differs from the `None` form.

## References

- [denomine-mcp release.yaml and build.yaml](https://github.com/Omochice/denomine-mcp/tree/main/.github/workflows)
- [ADR-002](./adr-002-native-backend-and-target-platforms.md) — platforms and toolchains.
- [ADR-005](./adr-005-tool-surface.md) — `redmoon_info`.
