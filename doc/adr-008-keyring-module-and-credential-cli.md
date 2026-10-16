# ADR-008: OS Keyring Module and Credential Subcommands

## Status

Proposed

## Context

denomine-mcp keeps the Redmine API key in the OS credential store, never in a file or an environment variable, and selects the Redmine instance by its endpoint URL (its ADR-0003 and ADR-0004).
Its CLI has `serve --endpoint <url> [--readonly]`, `login --endpoint <url>`, `logout --endpoint <url>`, and `list`.
`login` reads the key from a hidden prompt on a terminal, or from stdin otherwise, so the key never appears in shell history or the process list.
The keyring account is the canonical endpoint URL: lower-case scheme and host, no query, no fragment, no trailing slash.
It reached the store through the Rust `keyring` crate over FFI, and its Linux build uses the Secret Service, because kernel keyutils keys do not outlive the login session.

MoonBit has no keyring library, so `omochice/keyring` is written here ([ADR-001](./adr-001-five-module-moonbit-workspace.md)).
A probe called `SecItemCopyMatching` from a MoonBit native stub on macOS and got `-25300` (`errSecItemNotFound`) for an absent item, which shows the stub can reach the Keychain.
The same probe showed that a `-framework` link flag works only when written in the executable package, which a library cannot require of its users ([ADR-002](./adr-002-native-backend-and-target-platforms.md)).

## Decision Drivers

- **The key stays in the OS store** on every target platform.
- **The key never reaches an argument list**.
- **No build-time requirement on consumers** of the keyring module.

## Considered Options

### Option 1: Call `security` and `secret-tool` as processes

**Pros:**

- No C code.

**Cons:**

- `security add-generic-password` takes the password as an argument, so it appears in the process list, and Windows has no equivalent command for reading.

### Option 2: Reuse denomine-mcp's Rust cdylib

**Pros:**

- Already proven on all three platforms.

**Cons:**

- A Rust toolchain in every build, and a second library to ship next to the binary.

### Option 3: C stubs in a MoonBit module (chosen)

**Pros:**

- One self-contained module and one executable, with no extra toolchain.

**Cons:**

- Platform C code written and maintained here.

## Decision

We will write `omochice/keyring` as C stubs over each platform's credential API, and build the credential subcommands of redmoon on it.

### 1. The keyring API

```moonbit
pub fn get(service : String, account : String) -> String? raise KeyringError
pub fn set(service : String, account : String, secret : String) -> Unit raise KeyringError
pub fn delete(service : String, account : String) -> Unit raise KeyringError
pub fn list(service : String) -> Array[String] raise KeyringError
```

`KeyringError` distinguishes a store that cannot be reached at all (`NoStore`) from an operation the store refused (`Refused(code)`).

**Rationale**: these four are what the CLI uses; `NoStore` is separate because on Linux it means no Secret Service provider is running, which the user fixes differently from a refused write.

### 2. One backend per platform, loaded without link flags

| OS      | Store                                   | Access                                                          |
| ------- | --------------------------------------- | --------------------------------------------------------------- |
| macOS   | Keychain, generic passwords             | `dlopen` of `Security.framework` and `CoreFoundation.framework` |
| Linux   | Secret Service, through libsecret       | `dlopen("libsecret-1.so.0")`                                    |
| Windows | Credential Manager, generic credentials | `CredReadW` and friends, `#pragma comment(lib, "advapi32.lib")` |

**Rationale**: this is how `moonbitlang/async` loads its platform libraries, and it keeps every link requirement inside the module.

### 3. redmoon's CLI is denomine-mcp's

`serve`, `login`, `logout`, and `list` with the same options, messages, and endpoint canonicalization; the service name is `redmoon`.
The `license` subcommand of denomine-mcp is not carried over.

**Rationale**: the CLI is part of the behaviour to satisfy, and a separate service name keeps redmoon's credentials apart from denomine-mcp's on a machine that has both.

### 4. The hidden prompt lives in redmoon

A `tty` package in `omochice/redmoon` turns off echo with `termios` on macOS and Linux and with `SetConsoleMode` on Windows, and `login` falls back to reading all of stdin when stdin is not a terminal.

**Rationale**: a prompt is not part of a credential store, so it stays out of the keyring module.

## Consequences

### Positive

1. **The key is only ever in the OS store and in memory**.
2. **One executable** on every platform.
3. **A reusable keyring module** with no build requirements on its users.

### Negative

1. **Platform C code**, including Windows code that no maintainer can run locally.
2. **Run-time dependency on Linux**: without libsecret and a running Secret Service provider, `login` and `serve` fail.
3. **A key stored by denomine-mcp is not found** under the `redmoon` service name.

### Mitigations

- CI runs the keyring tests on each platform where a store is available, and the C stubs are kept to the four operations.
- The `NoStore` message names libsecret and the Secret Service, so the user knows what to install.
- The README tells denomine-mcp users to run `redmoon login` once per endpoint.

## Implementation Notes

- Secrets cross the C boundary as UTF-8 bytes, never as MoonBit strings held longer than the call.
- The Linux CI runner has no Secret Service by default; the keyring tests there either start one or are skipped explicitly, never silently.

## References

- [denomine-mcp ADR-0003 and ADR-0004](https://github.com/Omochice/denomine-mcp/tree/main/doc/adr)
- [ADR-002](./adr-002-native-backend-and-target-platforms.md) — why libraries load platform code without link flags.
- [ADR-009](./adr-009-testing-strategy.md) — how the CLI is tested without a real store.
