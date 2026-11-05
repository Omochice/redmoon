# ADR-035: Design Evolution from ADR-008

## Status

Accepted

## Context

[ADR-008](./adr-008-keyring-module-and-credential-cli.md) decided that `omochice/keyring` is written as C stubs over each platform's credential API and that redmoon's CLI repeats denomine-mcp's subcommands on top of it.
The decision stands, and the keyring API, the per-platform stores, and the four subcommands are as ADR-008 records them.

Four details of ADR-008 are no longer what the repository does.
Its Mitigations say that CI runs the keyring tests on each platform with a store, and its Implementation Notes say that the tests on the Linux runner are started or skipped explicitly, never silently; [ADR-029](./adr-029-testing-strategy.md) later made the store round trip opt-in and accepted that a plain `moon test` reports it as passed, so two Accepted ADRs disagree.
Its section 2 names one Linux library while the code opens three.
Its section 3 says that `serve` has the same options as denomine-mcp's, while `serve` has gained `--plugin` through three later ADRs.
Its Implementation Notes say that secrets never outlive the call, which the Darwin stub cannot fully honour.
ADR-008 also cites [ADR-009](./adr-009-testing-strategy.md) for how the CLI is tested, and ADR-029 has superseded ADR-009.

This ADR records those four changes so that the design-evolution record stays visible and ADR-008's stale sentences are not followed.

## Design Changes from ADR-008

### 1. The store round trip is opt-in, and a plain run reports it as passed

#### Original Design (ADR-008)

CI runs the keyring tests on each platform where a store is available, and on the Linux runner, which has no Secret Service by default, the tests either start one or are skipped explicitly, never silently.

#### Revised Design

The status mapping and the account-list parsing of `omochice/keyring` are plain unit tests that run everywhere.
The round trip that writes, reads, lists, and deletes an entry in the OS store runs only when `REDMOON_TEST_KEYRING=1` is set, which `task test:keyring` and `task test:keyring:coverage` do.

```moonbit
test "set, get, list and delete round-trip a secret" {
  guard store_test_service() is Some(service) else { return }
  ...
}
```

Without the variable the test returns early, and `moon test` reports it as passed.
Only the `test-macos` job of `ci.yaml` sets the variable, so the C stubs are exercised against a Keychain and against no other store in CI.

#### Rationale

MoonBit has no way to skip a test at run time, as ADR-029's Context records, so a test that cannot run is either reported as passed or kept out of the run altogether, and ADR-029 accepted the former as its Negative consequence 7.
The macOS runner has a Keychain out of the box, which is why ADR-029 section 7 runs the round trip there; the Linux runner has no Secret Service, and starting a provider on it was not done.
The Windows stub has no CI job at all, which [ADR-027](./adr-027-release-distribution.md) section 6 records for every Windows job.
Each stub is therefore exercised only where its store exists, and in CI that is the Darwin stub alone.

### 2. The Linux backend opens three libraries

#### Original Design (ADR-008)

The Linux row of the backend table reads `dlopen("libsecret-1.so.0")`.

#### Revised Design

The Linux stub opens `libsecret-1.so.0`, `libglib-2.0.so.0`, and `libgobject-2.0.so.0`, and reports `NoStore` when any of them is missing.
The password functions come from libsecret; `g_hash_table_lookup`, `g_hash_table_unref`, `g_error_free`, and `g_list_free` come from GLib; and `g_object_unref` comes from GObject.

#### Rationale

libsecret hands back GLib and GObject values, such as the `GHashTable` of an entry's attributes and the `GError` of a failed call, and freeing them needs the functions of the library that allocated them.
Both libraries are hard dependencies of libsecret, so a machine with libsecret has them, and the user still installs nothing beyond what ADR-008 named.

### 3. `serve` has an option denomine-mcp does not have

#### Original Design (ADR-008)

`serve`, `login`, `logout`, and `list` have the same options, messages, and endpoint canonicalization as denomine-mcp.

#### Revised Design

`serve` also takes a repeatable `--plugin` option, decided in [ADR-017](./adr-017-redmine-plugin-sdk-module.md) section 3, which registers the tools of a Redmine plugin the instance runs.
The known names are `issue_templates` from ADR-017, `agile` from [ADR-025](./adr-025-redmineup-agile-data.md), and `additional_tags` from [ADR-030](./adr-030-additional-tags-issue-tags.md).
`login`, `logout`, and `list` are unchanged.

#### Rationale

denomine-mcp speaks to Redmine itself only, so it has no reason for such an option, and the three ADRs above explain why redmoon needs one.

### 4. The Darwin stub cannot wipe the plaintext it reads

#### Original Design (ADR-008)

Secrets cross the C boundary as UTF-8 bytes, never as MoonBit strings held longer than the call.

#### Revised Design

That rule still holds for the MoonBit side.
On the C side, the Windows stub zeroes the credential blob with `SecureZeroMemory` before `CredFree`, and the Linux stub frees the password through `secret_password_free`, which libsecret wipes.
The Darwin stub copies the bytes out of the `CFData` that `SecItemCopyMatching` returns and then releases it with `CFRelease` without wiping it.

#### Rationale

`CFDataGetBytePtr` returns a `const` pointer into an immutable object, so writing through it is undefined behaviour, and CoreFoundation offers no call that wipes a `CFData` before releasing it.
The plaintext therefore stays in freed memory on macOS until it is reused, which is a limit of the platform API rather than a gap in the stub.

## Consequences

### Positive

1. **Two Accepted ADRs agree again** on how the keyring is tested, with ADR-029 as the record.
2. **The library table matches the code**, so a packager knows what a Linux machine needs.
3. **A reader of ADR-008 is sent to the plugin ADRs** for the one option `serve` has gained.
4. **The platform limit on wiping is written down**, so a later reader does not look for a wipe the API cannot provide.

### Negative

1. **The Linux and Windows stubs are not exercised in CI**: a regression in either shows up only on a developer machine that runs the opt-in round trip.
2. **The plaintext of a read key lingers in freed memory on macOS**, which the stub cannot prevent.

### Mitigations

- The three stubs share one `keyring_common.h` and one result buffer, so the platform-specific code is small and reviewed by hand.
- The lingering copy lives only in the process that already holds the key, and the process exits when `serve` ends.

## References

- [ADR-008](./adr-008-keyring-module-and-credential-cli.md) — the decision this ADR refines.
- [ADR-029](./adr-029-testing-strategy.md) — the opt-in round trip and the accepted silent pass.
- [ADR-017](./adr-017-redmine-plugin-sdk-module.md), [ADR-025](./adr-025-redmineup-agile-data.md), and [ADR-030](./adr-030-additional-tags-issue-tags.md) — the plugins that `--plugin` names.
- [ADR-027](./adr-027-release-distribution.md) — why no Windows job exists at the moment.
- [CFDataGetBytePtr](https://developer.apple.com/documentation/corefoundation/cfdatagetbyteptr) — the read-only pointer into a `CFData`.
