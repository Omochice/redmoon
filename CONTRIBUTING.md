# Contributing

The toolchain is managed with [Nix](https://nixos.org/).

Routine tasks are managed with [Task](https://taskfile.dev/).

```sh
nix develop
task check
task test
nix fmt
```

`task --list` shows the other tasks.

The integration tests need a running Redmine.
[doc/verification.md](./doc/verification.md) describes how to start and seed one.

```sh
task redmine:up
task redmine:seed
task test:integration
```

## Layout

Each SDK is a separate module so that another MoonBit program can use it without pulling in the server, as [ADR-001](doc/adr-001-five-module-moonbit-workspace.md) explains.

- `redmoon/` is the server and its CLI.
- `mcp/` is the MCP SDK.
- `schema/` is the typed schema DSL the tools are declared with.
- `redmine/` is the Redmine REST API SDK.
- `redmine-plugins/` covers the APIs of Redmine plugins.
- `keyring/` is the OS credential store binding.
- `integration-test/` holds the tests that run against a real Redmine.

The decisions behind the design are recorded as ADRs under [doc/](./doc/).

## Versioning

Follow [Semantic Versioning 2.0.0](https://semver.org/).

## Commit

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) and use the well-known [commit types](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional#type-enum).
