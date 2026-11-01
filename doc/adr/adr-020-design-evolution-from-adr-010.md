# ADR-020: Design Evolution from ADR-010

## Status

Proposed

## Context

[ADR-010](./adr-010-release-distribution.md) decided that each release job runs `moon build --target native --release` and uploads the executable it leaves under `_build/native/release/build/`.
The flake has since gained a `redmoon` package built with moon-nix, which compiles the workspace from the locked mooncakes index with the same C flags as `moon build --release`.
Keeping both meant the release assets and the Nix package came from two build paths that could drift apart.
This ADR records that the release build now goes through the flake package, so that ADR-010 is not followed into a `moon build` invocation and an output path the workflow no longer uses.

## Design Changes from ADR-010

### 1. Release jobs build the flake package

**Original Design (ADR-010)**: each job runs `moon build --target native --release` and uploads the renamed executable from `_build/native/release/build/<package path>/<name>.exe`.

**Revised Design**: each job runs `task build`, which builds the flake package and links the result at `_build/redmoon`; the workflow stages `_build/redmoon/bin/redmoon` under the asset name.

```yaml
build:
  desc: Build the release executable as the flake package and link it at _build/redmoon
  cmds:
    - nix build .#redmoon --out-link _build/redmoon
```

The build-info source is still stamped before the build, and the flake source includes the stamped file because it is tracked by git.

**Rationale**: one build path means the asset attached to a release is the binary `nix build github:Omochice/redmoon` produces, and the CI job that smoke-runs the asset also covers the Nix package.

## Consequences

### Positive

1. **Release assets and the Nix package are the same build**.
2. **The package closure is the stripped binary alone**, so the asset carries no store paths into the release.

### Negative

1. **Only platforms with a Nix toolchain can build a release asset**: moonbit-overlay publishes toolchains for aarch64-darwin and x86_64-linux only, so the Linux arm64 and Windows rows of ADR-010 cannot use this path.
2. **The build depends on the moon-nix fork branch** until its fixes land upstream.

### Mitigations

- Linux arm64 and Windows are not built at the moment; when they return, they need a `moon build` job of their own beside the Nix one.
- The fork branch is pinned in `flake.lock`, so a release only changes when the lock is updated.

## References

- [ADR-010](./adr-010-release-distribution.md) — the decision this ADR refines.
- [ADR-014](./adr-014-design-evolution-from-adr-010.md) — the earlier refinement of ADR-010.
- [moon-nix](https://github.com/moonbit-community/moon-nix) — the builder behind the flake package.
