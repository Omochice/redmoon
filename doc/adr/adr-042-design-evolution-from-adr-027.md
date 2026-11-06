# ADR-042: Design Evolution from ADR-027

## Status

Accepted

## Context

[ADR-027](./adr-027-release-distribution.md) section 5 records that every release asset is the flake package built on its own runner, and section 6 that only `aarch64-apple-darwin` and `x86_64-unknown-linux-gnu` are built, because moonbit-overlay ships a toolchain for those two platforms alone.
The decision as a whole stands: release-please owns the release, every module carries one version, the binary embeds `version.json`, and the build information is stamped before the build.

Two things learned after v0.5.0 change how the assets are built.

The Linux asset of v0.5.0 does not start on a machine without nix.
Its ELF interpreter is `/nix/store/...-glibc-2.44-57/lib/ld-linux-x86-64.so.2` and its rpath lists store paths, because a nix-built binary is linked against the nix glibc and the flake package strips debug information only.
The macOS asset links against `/usr/lib/libSystem.B.dylib` and is unaffected.
So the single build path of section 5 produced, for Linux, a binary that only nix users could run, and nix users already have the flake package.

The Windows and Linux arm64 jobs that section 6 deferred had never built anything.
Every run that included them, up to 2026-10-17, failed on all platforms while resolving `moonbitlang/async` from the registry, so `keyring_windows.c`, the Windows branch of `tty.c`, and the Schannel path of moonbitlang/async had never been compiled by this repository.
Building with the official installer on 2026-11-06 produced and smoke-ran all four targets of [ADR-002](./adr-002-native-backend-and-target-platforms.md), and the Linux binaries it produced have the system loader as their interpreter.

This ADR records the resulting changes so that a reader of ADR-027 does not expect the release asset to be the flake package, and so that the platform list that is actually built is written down.

## Design Changes from ADR-027

### 1. Every asset is built with the official toolchain on its own runner

#### Original Design (ADR-027 section 5)

Each job runs `task build`, which is `nix build .#redmoon --out-link _build/redmoon`, and copies the flake package's binary to `dist/redmoon-<target>`.
One build path means the asset is the binary `nix build github:Omochice/redmoon` produces.

#### Revised Design

Each job installs the MoonBit toolchain with the official installer (`unix.sh`, or `powershell.ps1` with MSVC on Windows), installs Task with its pinned setup action, stamps the build information, and runs `task build`, which is now `moon build --target native --release redmoon/src/cmd/redmoon`.
The binary is copied from `_build/native/release/build/omochice/redmoon/cmd/redmoon/redmoon.exe`, which is the name moon gives the native executable on every OS, to `dist/redmoon-<target>` with `.exe` appended on Windows.
On macOS and Linux the copy is stripped with `strip -S`, because the native toolchain leaves debug information in the binary; the MSVC build keeps its debug information in a separate file and is not stripped.
The smoke run with `--help` and the artifact upload are unchanged.

The flake package remains as `task build:flake` and as `nix build .#redmoon`, for nix users and for `nix flake check`; it is no longer what a release attaches.

#### Rationale

A binary linked on the runner against the system glibc or libSystem starts on any machine with that platform's loader, which is what a downloaded release asset has to do.
The installer path is the one moonbitlang/async's own CI uses on every OS, and it is the only path available on the two platforms moonbit-overlay does not cover, so using it everywhere gives the four assets one build path again, as ADR-027 wanted, without tying the asset to nix.

### 2. The installer takes the version the flake pins

#### Original Design (ADR-027)

The toolchain comes from moonbit-overlay through `flake.lock`; nothing outside nix needed the version.

#### Revised Design

`.github/workflows/toolchain.yaml` runs `moonc -v` in the nix devShell and parses the release name, `0.10.19+bee578715` at the time of writing, from its output.
`build.yaml` calls it as its first job and passes the result to every build job as `MOONBIT_INSTALL_VERSION`, which both official installers read.
`ci.yaml` and `release.yaml` keep calling `build.yaml` unchanged.

#### Rationale

The flake selects `pkgs.moonbit-bin.latest` of the locked overlay revision, so the version is not written anywhere in the repository and cannot be read without evaluating the flake.
Asking the pinned compiler itself keeps the installer in step with `flake.lock`, so a renovate update of the lock moves every runner together.
Reading the overlay's version file through the GitHub API would avoid one nix job but would copy the overlay's file layout into this repository's workflows; one job of about a minute was judged the smaller cost.

### 3. The four targets of ADR-002 are built, and Intel macOS is not supported

#### Original Design (ADR-027 section 6)

Only `aarch64-apple-darwin` and `x86_64-unknown-linux-gnu` are built; `aarch64-unknown-linux-gnu` and `x86_64-pc-windows-msvc` have no release asset or CI job, and dropping them for good has not been decided.

#### Revised Design

`build.yaml` builds all four targets of ADR-002 on `macos-15`, `ubuntu-latest`, `ubuntu-24.04-arm`, and `windows-latest`, on every pull request and every push to `main` as well as at release.
`x86_64-apple-darwin` is not a target: it has no release asset, no CI job, and no entry in any platform table, by decision rather than for the moment.
The unit tests keep running where they run today, on the nix runners; the installer jobs only compile the platform stubs and smoke-run the binary, by decision, because a test matrix across four runners costs more minutes per pull request than the platform-specific code justifies.

#### Rationale

Building with the official installer showed that the four targets build and that the Windows stubs compile under MSVC, so the reason section 6 deferred them, the missing toolchain, is gone once the official installer is used.
Neither the official `unix.sh` installer nor moonbit-overlay has a toolchain for Intel macOS, and nobody using redmoon has asked for one, so supporting it would add a third toolchain path for no user.

## Consequences

### Positive

1. **The Linux assets run on a plain Linux machine**, which the v0.5.0 asset did not.
2. **Windows and Linux arm64 users get a binary**, and their C stubs are compiled on every pull request.
3. **One build path for every asset**, as ADR-027 section 5 intended, now independent of which platforms the overlay covers.

### Negative

1. **The release build no longer goes through nix**, so an asset and `nix build .#redmoon` are built by different paths from the same compiler version; ADR-027 section 5's claim that the smoke run covers the Nix package no longer holds.
2. **A toolchain job runs before every build**, adding about a minute to each pull request and release.
3. **The unit tests still do not run on Windows or Linux arm64**, so a test that depends on the OS, such as a path separator, is caught only when someone builds the test matrix there.
4. **The installers are fetched over the network at build time** from `cli.moonbitlang.com`, pinned by version name rather than by hash.

### Mitigations

- `nix flake check` still builds the flake package on every pull request, so the nix path is exercised even though its binary is not the asset.
- The toolchain job runs once per workflow, not once per target.
- The one OS-dependent assertion found so far was rewritten to compare with `@fs.realpath`, and a platform-specific change can be tested on those runners with a temporary workflow.
- The version name carries the compiler's commit hash, and the same name is what the overlay's snapshot was taken from.

## References

- [ADR-027](./adr-027-release-distribution.md) — the decision this ADR refines.
- [ADR-002](./adr-002-native-backend-and-target-platforms.md) — the four target platforms and the toolchain per runner.
- [ADR-015](./adr-015-task-runner.md) — Task on every runner, installed by a setup action where nix is absent.
- [moonbitlang/async check.yml](https://github.com/moonbitlang/async/blob/main/.github/workflows/check.yml) — the official installer used on every OS.
- [MoonBit download page](https://www.moonbitlang.com/download) — the installers and the release names they accept.
