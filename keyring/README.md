# omochice/keyring

Four operations on the operating system's credential store, `get`, `set`, `delete`, and `list`, written as C stubs that reach each platform's library without link flags in the consumer's build, so a consumer adds nothing of its own.

The module covers the macOS Keychain, the Secret Service through libsecret on Linux, and the Windows Credential Manager.
It covers nothing else: no other store, no prompt for a secret, and no policy on what the service and account names mean.

On macOS the plaintext of a read secret stays in freed memory until it is reused, because CoreFoundation offers no call that wipes a `CFData` before releasing it.
The Linux and Windows stubs wipe the buffer before freeing it.
