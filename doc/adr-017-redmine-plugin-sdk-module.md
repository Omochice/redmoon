# ADR-017: A Separate Workspace Module for Redmine Plugin APIs

## Status

Proposed

## Context

Redmine itself has no issue templates.
The feature has been requested since 2008 ([Feature #1138](https://www.redmine.org/issues/1138), duplicated into [Feature #6715](https://www.redmine.org/issues/6715), still open), and instances that have templates get them from the [redmine_issue_templates](https://github.com/agileware-jp/redmine_issue_templates) plugin.
redmoon is used against such an instance, and a model creating an issue there cannot see the templates the project expects it to follow.

`omochice/redmine` is a typed client for the REST API of Redmine itself ([ADR-006](./adr-006-typed-redmine-sdk.md)).
A plugin's API is not part of it: it exists only where the plugin is installed, its shape is decided by the plugin's authors, and it changes when the plugin changes rather than when Redmine does.

The plugin's API was measured on Redmine 7.0.2 with the admin API key, against the verification Redmine of `compose.yaml`, which installs the plugin at commit `87360e7`, and against a throwaway instance with the plugin's latest tag, v1.2.2.
`demo-child` is a subproject of `demo` that inherits its templates.

| Request                                                                           | Answer                                                                                                                                                                                                                               |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `GET /projects/demo/issue_templates.json`                                         | `87360e7`: `200`, `{"global_issue_templates": [...], "inherit_templates": [...], "issue_templates": [...]}`; v1.2.2: `404` for every project, because the controller asks for a `json` view and the plugin has only `.api.rsb` views |
| `GET /projects/demo-child/issue_templates.json`                                   | `87360e7`: `500`, `undefined method 'tracker' for an instance of Tracker` from `index.api.rsb`, as soon as a project has inherited templates                                                                                         |
| `GET /projects/demo-child/issue_templates/list_templates.json?issue_tracker_id=1` | `200` on both versions, the same three arrays for one tracker, including inherited templates, but `tracker_name` holds the tracker id (`1`) for global templates                                                                     |
| `GET /global_issue_templates.json`                                                | `403`; the controller has no `accept_api_auth` and requires an administrator session                                                                                                                                                 |
| `POST /issue_templates/load.json?project_id=demo` with `template_id=1`            | `200` without any API key, `Content-Type: text/plain`, the template's columns as JSON text                                                                                                                                           |

`list_templates` is the only listing that accepts an API key and answers on both versions and for every project.
It already carries the global templates enabled for the project, so the global listing is not needed to reach them.
A global template has no `is_default`, `position`, or `enabled_sharing`, which project and inherited templates have.
`issue_title` and `note` are `null` when unset, and `@redmine.send` removes `null` members, so those keys arrive absent.

A module outside `omochice/redmine` cannot import that module's `internal/` packages ([ADR-016](./adr-016-design-evolution-from-adr-006.md)).
It can use the public `@redmine.send`, `RedmineError`, and `ProjectRef`, which ADR-016 kept public as the way to reach endpoints the SDK does not cover.

## Decision Drivers

- **Separate distribution**: a consumer of the Redmine SDK should not carry code for plugins its instance does not have, which is the driver [ADR-001](./adr-001-five-module-moonbit-workspace.md) applied to the five modules.
- **One role per unit**: Redmine's API and a plugin's API change for different reasons and on different schedules.
- **Room for more plugins**: issue templates are the first plugin, not the last one an instance may run.

## Considered Options

### Option 1: A package inside `omochice/redmine`

```text
redmine/src/issue_templates/
```

**Pros:**

- Reuses `internal/decode` and `internal/livetest` as they are.

**Cons:**

- The SDK of Redmine itself would describe an API that most Redmine instances do not serve, and its version would move with a plugin.

### Option 2: One module per plugin

```text
redmine_issue_templates/   module omochice/redmine_issue_templates
redmine_<next_plugin>/     module omochice/redmine_<next_plugin>
```

**Pros:**

- Each plugin's SDK is versioned with the plugin it follows.

**Cons:**

- A manifest, a `moon.work` entry, and a copy of the decode and live-test helpers per plugin.

### Option 3: One module for plugin APIs, one package per plugin (chosen)

```text
redmine-plugins/           module omochice/redmine-plugins
└── src/
    ├── issue_templates/   package omochice/redmine-plugins/issue_templates
    └── internal/          decode and live-test helpers shared by the plugin packages
```

**Pros:**

- Plugin code stays out of the Redmine SDK, and a consumer imports only the packages of the plugins it uses.
- The helpers that cannot be imported from `omochice/redmine` are written once for every plugin.

**Cons:**

- Every plugin package shares one version, so a breaking change for one plugin is a breaking change of the module.

## Decision

We will add a sixth workspace module, `omochice/redmine-plugins`, with one package per Redmine plugin, starting with `issue_templates`, and a read-only redmoon tool over it that `serve` registers only when asked to.

### 1. A module of its own, built on `@redmine.send`

**Change from**: five modules in `moon.work`.

**Change to**:

```text
members = ["./keyring", "./mcp", "./redmine", "./redmine-plugins", "./redmoon", "./schema"]
```

`omochice/redmine-plugins` depends on `omochice/redmine` and `moonbitlang/async`, and its packages call `@redmine.send`.
It keeps its own `internal/decode` and `internal/livetest`, which repeat the corresponding helpers of `omochice/redmine`.

**Rationale**: the split follows the drivers above, and the module boundary is the one the compiler already enforces, so the plugin code reaches Redmine only through the API that ADR-016 published for this purpose.
Widening `omochice/redmine`'s public surface to share its helpers was rejected because ADR-016 moved them into `internal/` so that consumers cannot depend on them.
The umbrella module was chosen over one module per plugin because the helpers are the same for every plugin and one shared version is acceptable while there is one plugin.

### 2. Only `list_templates`, one tracker at a time

```moonbit
pub async fn list(Redmine, ProjectRef, tracker_id~ : Int32) -> Templates raise RedmineError

pub(all) struct Templates {
  global : Array[GlobalTemplate]
  inherited : Array[ProjectTemplate]
  project : Array[ProjectTemplate]
}
```

**Rationale**: it is the only listing that accepts an API key and answers on every project and on both the latest tag and the current master, and it already includes the global templates.
The project index was the first choice because it lists every tracker in one request, and it was rejected because it cannot answer at all on v1.2.2 and fails on any project that inherits templates on master.
A tracker is known whenever an issue is about to be created, so asking for one costs a caller nothing it does not already have.
The types carry no `tracker_name`, because its type differs between template kinds in this response and `tracker_id` already names the tracker.
`load` is left out because it bypasses the API key and answers as `text/plain`, so a client built on it would depend on behaviour the plugin does not present as an API.
Global templates get their own type because they lack three fields, and folding them into one type would make those fields optional for project templates too.

### 3. `redmine_issue_templates`, enabled by `serve --plugin` and read-only

**Change from**: every tool is registered for every endpoint.

```json
"args": ["serve", "--endpoint", "https://redmine.example.com"]
```

**Change to**: a plugin's tools are registered only for the plugins named by a repeatable `--plugin` option.

```json
"args": ["serve", "--endpoint", "https://redmine.example.com", "--plugin", "issue_templates"]
```

| Tool                      | Actions | Write actions | Enabled by                 |
| ------------------------- | ------- | ------------- | -------------------------- |
| `redmine_issue_templates` | `list`  | none          | `--plugin issue_templates` |

`list` takes `project_id` as the other project-scoped tools do, and `tracker_id` for the reason above.
An unknown name fails at start-up with a message that lists the known ones.
A `404` from an instance that lacks the plugin despite the option is returned as any other `{ status, errors }` failure.

**Rationale**: whether a plugin is installed differs per Redmine, and `serve` already runs for one endpoint, so an option of `serve` is a per-instance setting without anything new to locate or parse.
It sits in the same `args` as `--readonly`, which is the only way redmoon is configured today.
A configuration file was rejected for now because its location, format, per-endpoint layout, and precedence over options would all have to be decided while it would hold this one setting; if more per-instance settings appear, it can accept the same names.
Probing the instance at start-up was rejected because it would add a request and a failure mode to every launch for one tool.
Registering the tool everywhere was rejected because on an instance without the plugin it is a tool a model can see and call but that can only fail.
The plugin offers no API to create or change templates, so the tool has no write actions and `--readonly` and `--plugin` combine freely.

## Consequences

### Positive

1. **The Redmine SDK stays about Redmine**: consumers that do not use the plugin see no trace of it.
2. **Templates become visible to a model**: issue creation can follow the project's templates.
3. **A place for the next plugin**: another plugin is a new package, not a new module.

### Negative

1. **Duplicated helpers**: `decode` and the live-test client exist in both `omochice/redmine` and `omochice/redmine-plugins`.
2. **Six manifests**: [ADR-001](./adr-001-five-module-moonbit-workspace.md)'s title and module table no longer describe the whole workspace.
3. **One more thing to configure**: the plugin's tool is absent until `--plugin issue_templates` is added to the server's arguments, and with the option on an instance that lacks the plugin it always answers `404`.
4. **Pinned to observed behaviour**: the plugin documents no API, so its shape is what its views render today.

### Mitigations

- The duplicated helpers are about twenty lines each and only ever read Redmine's JSON envelope, so they have little reason to diverge.
- This ADR records the sixth module; ADR-001's decision of how modules are split still holds and is applied here.
- The option is described in `serve --help`, and the tool description says that it needs the redmine_issue_templates plugin, so a model reading a `404` knows why.
- The verification Redmine installs the plugin and seeds a project template, a global template, and a subproject that inherits the project template, and live tests decode the real answer, so a change in the plugin's views fails a test.

## Implementation Notes

- `issue_title` and `note` are optional fields, because `@redmine.send` removes their `null` values.
- `tracker_name` is present in the response and ignored by the decoder.
- Live tests run against the projects seeded by `task redmine:seed`: `demo` holds the templates `Bug report` and `Global bug report` for tracker `1`, and its subproject `demo-child` inherits `Bug report`.

## References

- [ADR-001](./adr-001-five-module-moonbit-workspace.md) — how the workspace is split into modules.
- [ADR-005](./adr-005-tool-surface.md) — the tool table this ADR extends.
- [ADR-016](./adr-016-design-evolution-from-adr-006.md) — internal packages and `send` as the public escape hatch.
- [agileware-jp/redmine_issue_templates](https://github.com/agileware-jp/redmine_issue_templates) — the plugin, at commit `87360e7db5f274b3572234c3e1806aeb2772f409`.
