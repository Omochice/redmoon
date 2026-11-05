# ADR-041: Design Evolution from ADR-035

## Status

Accepted

## Context

[ADR-035](./adr-035-design-evolution-from-adr-008.md) section 2 records that the Linux keyring stub opens `libsecret-1.so.0`, `libglib-2.0.so.0`, and `libgobject-2.0.so.0`, and that a machine with libsecret has all three.
The decision stands, and the stub still loads every library with `dlopen` so that a binary runs on a machine without libsecret.

What ADR-035 does not record is how the stub decides that a failed call means no Secret Service is running, which is the `NoStore` case [ADR-008](./adr-008-keyring-module-and-credential-cli.md) section 2 separates from `Refused` because the user fixes it differently.
The stub searched the `GError` message for `org.freedesktop.secrets`, `D-Bus`, or `dbus`.
That text follows GLib's version and the locale, so the same failure on a system in another language reached the user as `Refused` with a bare code and no hint to start a provider.
Fixing that needs the error domains that GIO exports, so the stub now opens a fourth library, and section 2 of ADR-035 names one library too few.

This ADR records that change so that the design-evolution record stays visible and a packager reading ADR-035 does not list three libraries where four are opened.

## Design Changes from ADR-035

### 1. The Linux backend opens GIO and classifies `NoStore` by error domain

#### Original Design (ADR-035)

The Linux stub opens `libsecret-1.so.0`, `libglib-2.0.so.0`, and `libgobject-2.0.so.0`, and reports `NoStore` when any of them is missing.

#### Revised Design

The Linux stub also opens `libgio-2.0.so.0`, and reports `NoStore` when any of the four is missing.
From GIO it resolves `g_dbus_error_quark` and `g_io_error_quark`, and a failed call is `NoStore` when its `GError` has the `GDBusError` domain with a code that means the service is absent or could not be started, or the `GIOError` domain with any code other than a relayed remote error.

```c
static int no_store_error(const GError *err) {
  if (err->domain == g_dbus_error_quark()) {
    return err->code == G_DBUS_ERROR_SERVICE_UNKNOWN || err->code == G_DBUS_ERROR_NAME_HAS_NO_OWNER ||
           err->code == G_DBUS_ERROR_NO_SERVER ||
           (err->code >= G_DBUS_ERROR_SPAWN_EXEC_FAILED && err->code <= G_DBUS_ERROR_SPAWN_NO_MEMORY);
  }
  return err->domain == g_io_error_quark() && err->code != G_IO_ERROR_DBUS_ERROR;
}
```

The codes are written into the stub as the positions they hold in `GDBusError` and `GIOErrorEnum` of `gio/gioenums.h`, which are ABI, because the stub includes no GLib header.
Every other failed call is `Refused` with the `GError` code, as before.

#### Rationale

A `GError` carries its origin as a domain quark and a code, and those are the stable part of the error; the message is composed for a human and GLib is free to reword or translate it.
A domain error from GDBus about an unknown or unowned name, or a GIO error that is not a relayed remote error, means the bus or the Secret Service could not be reached before any store was spoken to, which is exactly the situation `NoStore` exists for.
The quarks are functions exported by libgio, and libgio is a hard dependency of libsecret, so the fourth library costs the user nothing that ADR-035 did not already assume.

## Consequences

### Positive

1. **`NoStore` is reported on a non-English system**, so the message that names libsecret and a provider reaches the user who needs it.
2. **The library list matches the code again**, so a packager knows that a Linux machine needs GIO as well.

### Negative

1. **Six enum positions are copied by hand** from `gio/gioenums.h`, and a reader has to trust the comment that they are ABI.

### Mitigations

- The positions are ABI because GIO is a shared library whose callers compile the values in, so they cannot move without breaking every program on the system.

## References

- [ADR-035](./adr-035-design-evolution-from-adr-008.md) — the decision this ADR refines.
- [ADR-008](./adr-008-keyring-module-and-credential-cli.md) — why `NoStore` is separate from `Refused`.
- [GError](https://docs.gtk.org/glib/error-reporting.html) — the domain and code of a GLib error.
- [GDBusError](https://docs.gtk.org/gio/error.DBusError.html) and [GIOErrorEnum](https://docs.gtk.org/gio/enum.IOErrorEnum.html) — the domains the stub matches.
