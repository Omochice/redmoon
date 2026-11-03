# omochice/keyring

Four operations on the operating system's credential store, `get`, `set`, `delete`, and `list`, written as C stubs that reach each platform's library without link flags in the consumer's build, so a consumer adds nothing of its own.

The module covers the macOS Keychain, the Secret Service through libsecret on Linux, and the Windows Credential Manager.
It covers nothing else: no other store, no prompt for a secret, and no policy on what the service and account names mean.

[ADR-008](../doc/adr/adr-008-keyring-module-and-credential-cli.md) records why the module exists and how each platform is reached, and [ADR-035](../doc/adr/adr-035-design-evolution-from-adr-008.md) records how it is tested and what the Darwin stub cannot do.
