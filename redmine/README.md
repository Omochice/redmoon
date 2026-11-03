# omochice/redmine

A typed client for the REST API of Redmine itself, with one package per resource, built on `moonbitlang/async`.

The resource packages are `issues`, `attachments`, `relations`, `time_entries`, `versions`, `wiki`, `queries`, `search`, `memberships`, and `enumerations`.
The root package holds the client, `RedmineError`, and `send`, which reaches any endpoint the packages do not cover.
The module covers nothing a plugin adds to Redmine; those APIs live in [omochice/redmine-plugins](../redmine-plugins/README.md).

[ADR-026](../doc/adr/adr-026-typed-redmine-sdk.md) is the consolidated record of the SDK, and [ADR-023](../doc/adr/adr-023-design-evolution-from-adr-007.md) records how a failure is reported.
