# ADR-019: The Agile Data of RedmineUP Agile as a Second Plugin Package

## Status

Proposed

## Context

Instances that plan work on agile boards get them from the RedmineUP Agile plugin, and the plugin keeps each issue's story points, sprint, and board position in a row of its own, `agile_data`, outside Redmine's issue.
`redmine_issues` cannot read or write that row, so a model working on such an instance cannot estimate an issue or move it between sprints.

[ADR-017](./adr-017-redmine-plugin-sdk-module.md) put the API of the redmine_issue_templates plugin into `omochice/redmine-plugins` and left that module as the place for the next plugin.

ADR-017 measured its plugin against the verification Redmine.
RedmineUP distributes the Agile plugin only after registration and publishes no repository of its source, and the verification Redmine does not install it.
The shapes below are read instead from the source of the free edition, redmine_agile 1.7.0 Light, as archived at [jirutka/redmine_agile](https://github.com/jirutka/redmine_agile) at commit `2032483`, and are cross-checked against [jztan/redmine-mcp-server](https://github.com/jztan/redmine-mcp-server), which already reads and writes the row.
None of them has been observed on a running instance.

| Source                                     | What it says                                                                                                                                                         |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Routes                                     | `member { get "agile_data", to: "agile_boards#agile_data" }` on issues, so `GET /issues/{id}/agile_data.json`                                                        |
| `AgileBoardsController`                    | `accept_api_auth :agile_data`, guarded by `view_agile_queries` in the project module `agile`; `return render_404 unless @agile_data`                                 |
| `agile_data.api.rsb`                       | `{"agile_data": {"id", "issue_id", "position", "story_points", "agile_sprint_id"}}`, all integers                                                                    |
| Schema and `AgileData` model               | `position`, `story_points`, and `agile_sprint_id` are nullable; `story_points` is validated as an integer `>= 0`, `nil` allowed                                      |
| Issue patch                                | `safe_attributes 'agile_data_attributes'` only for a new issue or a user allowed to `edit_issues`; `accepts_nested_attributes_for :agile_data` without `update_only` |
| jztan/redmine-mcp-server `tools/issues.py` | writes with `PUT /issues/{id}.json` and `{"issue": {"agile_data_attributes": {...}}}`, after reading the row to carry its `id` forward                               |

Without `update_only`, Rails treats a nested payload without the row's `id` as a new row that replaces the old one, so a write that names only the sprint nulls the story points and the position.
A `404` from the read means that the issue has no row yet or that the plugin is absent, and a `403` means that the project lacks the Agile module or the role lacks `view_agile_queries`.
`@redmine.send` removes `null` members from an answer but sends a request body as it is given, so a `null` in a write reaches the plugin.

## Decision Drivers

- **No accidental loss**: a caller that changes one field must not erase the others.
- **One role per unit**: [ADR-017](./adr-017-redmine-plugin-sdk-module.md) keeps a plugin's API out of the code for Redmine itself.
- **Opt-in per instance**: a plugin's tool exists only where `serve --plugin` names the plugin.

## Considered Options

### Option 1: Agile fields spliced into `redmine_issues`

```json
{"update": {"id": 42, "subject": "...", "story_points": 3}}
```

**Pros:**

- One call reads or writes an issue together with its agile data, as jztan/redmine-mcp-server does.

**Cons:**

- `redmine_issues` would describe and accept fields that most instances do not have, or change its schema with `--plugin`.
- A show would need a second request whose failure has to be either reported, failing a read of the issue itself, or swallowed, hiding why the fields are missing.

### Option 2: A separate `redmine_agile` tool over a package of `omochice/redmine-plugins` (chosen)

```json
{"update": {"issue_id": 42, "story_points": 3}}
```

**Pros:**

- The issue tools stay unchanged on every instance, and the plugin's failures belong to the tool that calls the plugin.

**Cons:**

- Reading an issue and its agile data takes two tool calls.

### Option 3: Sprint and board listings as well

```json
{"list_sprints": {"project_id": "demo"}}
```

**Pros:**

- A model could look up the id of a sprint by its name.

**Cons:**

- The Light edition has the `agile_sprints` table but no controller for it; the sprint API, `/projects/{id}/agile_sprints.json`, exists only in the paid Pro edition.
- The board, `GET /projects/{id}/agile/board`, answers only HTML and JavaScript and does not accept an API key, so there is no board API to call.

## Decision

We will add `agile` as the second package of `omochice/redmine-plugins`, covering only the per-issue agile data, and a `redmine_agile` tool over it that `serve --plugin agile` registers.

### 1. `get` and a carry-forward `update` in the SDK

**Change from**: no client for the plugin.

**Change to**:

```moonbit
pub async fn get(Redmine, issue_id : Int32) -> AgileData raise RedmineError

pub async fn update(Redmine, issue_id : Int32, Update) -> Unit raise RedmineError

pub(all) struct AgileData {
  id : Int32
  issue_id : Int32
  story_points : Int32?
  agile_sprint_id : Int32?
  position : Int32?
}

pub(all) struct Update {
  story_points : Clearable[Int32]?
  agile_sprint_id : Clearable[Int32]?
  position : Clearable[Int32]?
}
```

`update` reads the row first, sends its `id` and every value it holds, and overlays the requested changes.
A `404` from the read lets the write go ahead without an `id`, which creates the row; any other failure of the read is raised and nothing is written.
`Clear` is sent as `null`, which empties a story point estimate and takes the issue out of its sprint.

**Rationale**: the replacement behaviour is a property of the plugin, so the package that speaks the plugin's API is where it is contained, and no caller of the SDK can null a field by forgetting to carry it.
Leaving the read to the tool layer was rejected because every other consumer of the SDK would then have to know about the same trap.
Aborting on a failed read other than `404` was chosen because a write without the row's `id` would erase values that could not be read, so a partial answer is worse than none.
`Clearable` is reused from `omochice/redmine` so that "leave alone", "empty", and "set" mean what they mean for an issue.
`agile_sprint_id: 0`, which the reference also accepts for leaving a sprint, is not offered, because `null` already says it for a nullable column and one spelling is easier to describe.

### 2. `redmine_agile`, enabled by `serve --plugin agile`

```json
"args": ["serve", "--endpoint", "https://redmine.example.com", "--plugin", "agile"]
```

| Tool            | Actions         | Write actions | Enabled by       |
| --------------- | --------------- | ------------- | ---------------- |
| `redmine_agile` | `get`, `update` | `update`      | `--plugin agile` |

Both actions take `issue_id`; `update` also takes `story_points`, `agile_sprint_id`, and `position`, each optional and each clearable with `null`.
`--readonly` drops `update` from the schema as it drops the write actions of the other tools ([ADR-005](./adr-005-tool-surface.md)).
The description says that the tool needs the RedmineUP Agile plugin and the Agile module on the issue's project.

**Rationale**: the opt-in follows ADR-017 for the same reason, that redmoon cannot tell which plugins an instance runs.
A tool of its own was chosen over Option 1 because a plugin's fields would otherwise appear in a core tool on instances that lack the plugin.
The position is taken as `position`, its wire name, and not also as the `agile_position` alias of the reference, because two names for one argument would both have to be described and would conflict when given together.

### 3. Failures are reported, not swallowed

A `403` or `404` from either action is returned as the `{ status, errors }` failure of every other tool.

**Rationale**: the reference omits the agile fields when their read fails, which leaves a model unable to tell a missing module from an issue without an estimate.
A missing plugin, a missing module, a missing permission, and a missing row each have a remedy, and the status is what lets a model or a user find it.

## Consequences

### Positive

1. **Estimates and sprints become reachable**: a model can read and change the agile data of an issue.
2. **One safe write path**: the replacement trap of the nested attributes is handled once, in the SDK.
3. **The plugin stays opt-in**: instances without the plugin see no new tool.

### Negative

1. **Unmeasured shapes**: the types follow the plugin's source and a third-party client, not an answer observed from Redmine, and the Pro edition, whose source is not public, may answer differently.
2. **No live test**: unlike ADR-017's package, nothing in the integration tests exercises this package.
3. **Two requests per write, without a lock**: a change made between the read and the write is overwritten with the values read.
4. **Sprint ids are opaque**: without the sprint API a model has to be given the id of a sprint.

### Mitigations

- The decoder ignores unknown keys and treats the three nullable fields as optional, so a Pro answer with more keys still decodes; a shape mismatch is reported as a `Transport` failure rather than misread.
- The source commit is cited here, so a later measurement can compare against what this ADR assumed, and an instance with the plugin can add a live test then.
- The window between the read and the write is one round trip, and a caller that needs to know the result reads the row again with `get`.
- The description says where a sprint id comes from, and the sprint listing can be added as an action for instances with the Pro edition if one is needed.

## Implementation Notes

- `issue_id` is decoded but not carried into the write, because the nested attributes set it from the issue.
- A write needs `edit_issues` on the project in addition to the Agile module; Redmine ignores the attributes without an error otherwise, as it ignores any attribute a user may not set.
- The carry-forward is a pure function from the current row and the requested changes to the request body, so it is unit-tested without a Redmine.

## References

- [ADR-005](./adr-005-tool-surface.md) — the tool table this ADR extends.
- [ADR-017](./adr-017-redmine-plugin-sdk-module.md) — the plugin module, the `--plugin` option, and the measured shapes this ADR cannot match.
- [jirutka/redmine_agile](https://github.com/jirutka/redmine_agile) — an archive of redmine_agile 1.7.0 Light, at commit `2032483b81e77c6dec3ee6dec07d820d5b9e42a9`.
- [jztan/redmine-mcp-server](https://github.com/jztan/redmine-mcp-server) — `src/redmine_mcp_server/tools/issues.py`, the reference for the carry-forward write.
- [RedmineUP Agile](https://www.redmineup.com/pages/plugins/agile) — the plugin.
