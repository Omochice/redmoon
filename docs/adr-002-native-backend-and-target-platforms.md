# ADR-002: Native Backend on moonbitlang/async for macOS, Linux, and Windows

## Status

Proposed

## Context

An MCP client starts redmoon as a local process and talks to it over stdio, so redmoon has to be a binary a user can run without a runtime installed.
It also needs an HTTPS client, asynchronous stdin and stdout, files, and a way to call the OS credential store.

MoonBit compiles to WebAssembly, JavaScript, and native code through C.
Only the native backend gives a standalone executable and direct C calls.

`moonbitlang/async` 0.22.5 provides the I/O for the native backend: HTTP and TLS, stdio, file system, and processes.
A probe built with it on macOS fetched `https://www.redmine.org/projects/redmine/issues.json` with status 200 and read a line from stdin.
Its TLS loads the platform library at run time: `dlopen("/usr/lib/libssl.48.dylib")` on macOS, `dlopen("libssl.so.3")` on Linux, and Schannel through `#pragma comment(lib, "secur32.lib")` on Windows.
Its own CI runs `moon test` on `ubuntu-latest`, `macos-14`, and `windows-latest`, installing MSVC with `ilammy/msvc-dev-cmd` and MoonBit with the official `powershell.ps1` on Windows.

The development toolchain comes from [moonbit-overlay](https://github.com/moonbit-community/moonbit-overlay), which packages MoonBit for `aarch64-darwin` and `x86_64-linux` only.
MoonBit has no build for Intel macOS and does not cross-compile, so every target is built on a runner of the same OS and architecture.

denomine-mcp ships macOS (Apple silicon and Intel), Linux (x86_64 and arm64), and Windows (x86_64) binaries.

## Decision Drivers

- **Single executable**: the user installs one file.
- **Platform reach**: the platforms denomine-mcp reaches, as far as the toolchain allows.
- **Reproducible toolchain**: the compiler version is pinned and the same locally and in CI.

## Considered Options

### Option 1: JavaScript backend on Node.js

**Pros:**

- Runs wherever Node.js does, including Intel macOS.

**Cons:**

- The user needs Node.js, and the OS credential store is out of reach without a native addon.

### Option 2: Native backend, macOS and Linux only

**Pros:**

- Every build runs in the nix devShell.

**Cons:**

- Windows users, who denomine-mcp serves, are left out.

### Option 3: Native backend on all three operating systems (chosen)

**Pros:**

- One executable per platform, with direct access to the OS credential store.

**Cons:**

- The Windows build cannot use nix.

## Decision

We will build redmoon with the native backend on `moonbitlang/async` and distribute it for the platforms below.

| Asset                       | Runner             | Toolchain                   |
| --------------------------- | ------------------ | --------------------------- |
| `aarch64-apple-darwin`      | `macos-15`         | nix devShell                |
| `x86_64-unknown-linux-gnu`  | `ubuntu-latest`    | nix devShell                |
| `aarch64-unknown-linux-gnu` | `ubuntu-24.04-arm` | official installer          |
| `x86_64-pc-windows-msvc`    | `windows-latest`   | official installer and MSVC |

### 1. The nix devShell is the reference toolchain

The flake applies `moonbit-overlay.overlays.default` and puts `pkgs.moonbit-bin.latest` in the devShell, pinned by `flake.lock`.
The two runners without nix install the same version by setting `MOONBIT_INSTALL_VERSION` for the official installer.

**Rationale**: nix pins the compiler where it can, and the installer's version variable is the only way to match that pin where nix cannot run.

### 2. Platform libraries are loaded the way `moonbitlang/async` loads them

Code that calls a platform library uses `dlopen` on macOS and Linux and `#pragma comment(lib, ...)` on Windows, rather than link flags in `moon.pkg`.

**Rationale**: a probe showed that `cc-link-flags` such as `-framework Security` take effect only in the executable package, not in the library that needs them, and `moon.pkg` gives no per-OS switch.
Following `moonbitlang/async` keeps every library self-contained, and a consumer of an SDK adds nothing to its own build.

## Consequences

### Positive

1. **No runtime to install**: each asset is one executable.
2. **Windows included from the start**.

### Negative

1. **No Intel macOS**: denomine-mcp users on Intel Macs have no binary.
2. **Two toolchain sources**: Linux arm64 and Windows use the installer, so their compiler is matched to the pin by version name only.
3. **Windows is verified only in CI**: no maintainer machine runs Windows.
4. **Run-time library lookup**: on Linux, a missing `libssl.so.3` or libsecret is reported when a request or a credential call is made, not at start-up.

### Mitigations

- The README states that Intel macOS has no binary, and the asset is added once MoonBit publishes a toolchain for it.
- CI prints `moon version --all` on every runner, so a mismatch is visible in the log.
- CI runs the unit tests on Windows for every pull request, not only at release.
- The failure message names the library that could not be loaded.

## References

- [moonbitlang/async check.yml](https://github.com/moonbitlang/async/blob/main/.github/workflows/check.yml) — Windows CI with MSVC.
- [mizchi/pkfire pkl-publish.yml](https://github.com/mizchi/pkfire/blob/main/.github/workflows/pkl-publish.yml) — per-runner builds and the missing Intel macOS toolchain.
- [ADR-008](./adr-008-keyring-module-and-credential-cli.md) — the credential store calls this applies to.
- [ADR-010](./adr-010-release-distribution.md) — how the assets are released.
