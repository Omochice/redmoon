# ADR-001: Five MoonBit Modules in One Workspace

## Status

Proposed

## Context

redmoon is a Redmine MCP server written in MoonBit.
Its required behaviour is the one of [denomine-mcp](https://github.com/Omochice/denomine-mcp), a Deno implementation of the same server.

denomine-mcp consumes three things it did not have to write: the official MCP TypeScript SDK, `@omochice/redmine` for the Redmine REST API, and the Rust `keyring` crate behind an FFI shim.
None of them has a usable MoonBit counterpart.
The mooncakes registry has several MCP packages and no Redmine or OS keyring package, and the schema library closest to valibot, `mizchi/jsonschema`, cannot express what the tool surface needs (see [ADR-003](./adr-003-typed-schema-dsl.md)).

Each of these pieces is therefore written here, and each is also something another MoonBit program could reuse.
How they are split decides what can be published and versioned on its own.

MoonBit has two levels of unit.
A module owns a `moon.mod`, is the unit published to mooncakes, and carries a version.
A package is a directory with a `moon.pkg` inside a module.
A `moon.work` file lists modules that resolve each other from the local tree, which was confirmed with moon 0.1.20261012: a member importing `omochice/kr@0.1.0` built against the sibling directory without publishing it.

## Decision Drivers

- **Separate distribution**: each SDK should be usable without pulling the application or the other SDKs.
- **One role per unit**: a unit should not mix concerns that change for different reasons.
- **Atomic changes**: a change that crosses an SDK and the application should land in one commit and one pull request.

## Considered Options

### Option 1: One module, one package per concern

```text
omochice/redmoon
├── keyring/
├── redmine/
└── ...
```

**Pros:**

- One version, one manifest, one release.

**Cons:**

- A program that only needs the keyring depends on all of redmoon, and every SDK is versioned with the application.

### Option 2: One repository per module

**Pros:**

- Each SDK has its own history and issue tracker.

**Cons:**

- A change across an SDK and the application needs coordinated releases before it can be tested together.

### Option 3: Several modules in one repository, joined by `moon.work` (chosen)

```text
redmoon/            (this repository)
├── moon.work
├── schema/         module omochice/schema
├── mcp/            module omochice/mcp
├── redmine/        module omochice/redmine
├── keyring/        module omochice/keyring
└── redmoon/        module omochice/redmoon
```

**Pros:**

- Each SDK is published and versioned on its own, yet a cross-module change is one commit.

**Cons:**

- Five manifests, and a dependency between members has to be kept in step with what is published.

## Decision

We will keep five modules in this repository and list them in `moon.work`.

### 1. The modules and their roles

| Module             | Role                                                   | Depends on                    |
| ------------------ | ------------------------------------------------------ | ----------------------------- |
| `omochice/schema`  | One definition yields a JSON Schema and a typed parser | core only                     |
| `omochice/mcp`     | MCP server over stdio                                  | `schema`, `moonbitlang/async` |
| `omochice/redmine` | Typed Redmine REST client                              | `moonbitlang/async`           |
| `omochice/keyring` | OS credential store                                    | core only                     |
| `omochice/redmoon` | CLI, tools, and the wiring of the above                | all of the above              |

**Rationale**: the split follows what each piece knows about.
`redmine` knows nothing of MCP and `mcp` knows nothing of Redmine, so either can be released without the other, and only `redmoon` knows both.
`schema` is apart from `mcp` because validating a JSON value into a typed value is useful outside MCP, for example for configuration files.

### 2. The modules share the `omochice/` prefix and no project prefix

**Rationale**: the names say what each SDK is for any consumer, while a `redmoon_` prefix would tie a general SDK to one application.

## Consequences

### Positive

1. **Reusable SDKs**: each SDK can be added to another program alone.
2. **Atomic cross-module changes**: the workspace builds the members against each other without publishing.

### Negative

1. **More manifests**: five `moon.mod` files, and CI has to check every member.
2. **Version bookkeeping**: a member's import names a version, which has to match what is published once the SDKs are released.
3. **Broad names**: `omochice/keyring` and `omochice/schema` are generic, and the scope a name implies is wider than what the first version covers.

### Mitigations

- CI runs `moon check` and `moon test` from the workspace root, which covers every member at once.
- `moon work sync` writes the workspace versions into the member manifests.
- Each module's README states what it covers and what it does not.

## References

- [ADR-003](./adr-003-typed-schema-dsl.md) — why the schema DSL is its own module.
