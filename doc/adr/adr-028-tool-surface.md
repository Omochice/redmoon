# ADR-028: One Action-Keyed Tool per Redmine Resource, in snake_case, with File-Backed Text

## Status

Accepted (refined by [ADR-034](./adr-034-design-evolution-from-adr-028.md))

## Context

This ADR consolidates [ADR-005](./adr-005-tool-surface.md), [ADR-019](./adr-019-design-evolution-from-adr-005.md), and [ADR-021](./adr-021-design-evolution-from-adr-005.md), which together decided the tools redmoon exposes over MCP.
ADR-005 set the surface, and the two later ADRs each refined part of it, so a reader had to read three files in order to learn the surface as it stands.
This ADR restates the decision with every refinement folded in and replaces the three as the primary record.

The behaviour redmoon has to satisfy is that of denomine-mcp, whose tool surface was settled across its ADR-0001, ADR-0002, ADR-0012, ADR-0015, ADR-0016, and ADR-0017, and the decisions below start from that surface.
One premise behind it binds redmoon as well: the Anthropic Messages API answers HTTP 400 to an `input_schema` with `oneOf`, `anyOf`, or `allOf` at the top level, and one such tool fails every request.

denomine-mcp names its arguments in camelCase (`projectId`, `statusId`) and returns camelCase keys, because `@omochice/redmine` converts Redmine's snake_case responses.
MoonBit names fields in snake_case, Redmine's JSON is snake_case, and redmoon's SDK returns typed values whose fields mirror that JSON ([ADR-026](./adr-026-typed-redmine-sdk.md)).

Using that surface exposed two gaps that strict parity with denomine-mcp could not close.
A model asked to create an issue and assign it to a group could not find the group's id, because `assigned_to_id` takes the id of a user or a group and no tool listed the users or groups of a project.
The only way to learn such an id was to find an existing issue already assigned to the principal, which fails for a principal that has never been assigned anything.
A model rewriting a large issue description also sometimes emitted malformed JSON, because the whole body had to be escaped inside `{ "update": { "description": "..." } }`, and the same risk applies to journal notes and to wiki text.

redmoon runs over stdio beside the MCP client, and the model there has its own tools to write a file and to replace an exact string in one.

Two neighbouring decisions are recorded elsewhere and only summarised here.
How an SDK error becomes the failure payload is decided by [ADR-007](./adr-007-error-handling.md) and [ADR-023](./adr-023-design-evolution-from-adr-007.md).
Why the tools of Redmine plugins exist and why they are opt-in is decided by [ADR-017](./adr-017-redmine-plugin-sdk-module.md), [ADR-025](./adr-025-redmineup-agile-data.md), and [ADR-030](./adr-030-additional-tags-issue-tags.md).

## Decision

We will expose one action-keyed tool per Redmine resource, with every argument and response key in snake_case, starting from denomine-mcp's tools, actions, and modes and extending them where they left a model unable to finish a common request.

### 1. The tools

The table below lists every tool and the write actions `--readonly` removes from it; the other actions are read in each tool's schema.
A tool whose Enabled by column names a `--plugin` value is registered only when `serve` is given that value.

| Tool                      | Write actions                                              | Enabled by                 |
| ------------------------- | ---------------------------------------------------------- | -------------------------- |
| `redmine_issues`          | `create`, `update`, `delete`, `update_note`, `delete_note` | always                     |
| `redmine_wiki_pages`      | `create`, `update`, `delete`                               | always                     |
| `redmine_versions`        | `create`, `update`, `delete`                               | always                     |
| `redmine_issue_relations` | `create`, `delete`                                         | always                     |
| `redmine_search`          | none                                                       | always                     |
| `redmine_time_entries`    | `create`, `update`, `delete`                               | always                     |
| `redmine_enumerations`    | none                                                       | always                     |
| `redmine_memberships`     | none                                                       | always                     |
| `redmine_attachments`     | `attach`                                                   | always                     |
| `redmoon_info`            | none                                                       | always                     |
| `redmine_issue_templates` | none                                                       | `--plugin issue_templates` |
| `redmine_agile`           | `update`                                                   | `--plugin agile`           |
| `redmine_tags`            | `add`, `remove`                                            | `--plugin additional_tags` |

Each tool keeps the arguments, constraints, defaults, and description text of its denomine-mcp counterpart, with names converted to snake_case, except where a later section of this decision adds to them.
In `--readonly` mode the write actions are left out of both the schema and the description, so a call naming one fails as `unknown action` like any other unknown key.
`download` and a `show` that saves text to a file stay in `--readonly`, because they write only to the caller's own filesystem and change nothing in Redmine.

#### Rationale

The tool list, the per-action shapes, and the descriptions are what a model sees, so keeping them is what keeps the behaviour models already relied on.
Removing a write action from the schema makes a write inexpressible rather than rejected, so a read-only server cannot be talked into one.

### 2. snake_case arguments and responses

#### Rationale

denomine-mcp's `{ "list": { "projectId": 1 } }` answered with `assignedTo` becomes `{ "list": { "project_id": 1 } }` answered with `assigned_to`.
A model reads `project_id` in a response and passes it back unchanged, and the same names hold from the Redmine wire through the SDK structs to the tool, so no layer renames anything.
Keeping denomine-mcp's camelCase would have needed a renaming layer between the SDK and the tools in both directions.

### 3. The action-keyed schema is a combinator of `omochice/schema`

Each tool's input is built with `keyed` from [ADR-003](./adr-003-typed-schema-dsl.md), one entry per action, as in the sketch below.

```moonbit
@schema.keyed([
  ("list", list_input),
  ("show", show_input),
  ...
])
```

`keyed` emits `{ type: "object", properties: { <action>: <schema> }, minProperties: 1, maxProperties: 1, additionalProperties: false }` and parses into the tool's action enum.
An action spread over several shapes, such as `update_note` or a `list` of issues that takes either filters or a saved `query_id`, picks its shape by the keys it carries and is advertised as an `anyOf` inside its own property.
`--readonly` builds the list without the write actions.

#### Rationale

The top level stays a plain object, which is what the Anthropic Messages API accepts.
denomine-mcp re-keyed a discriminated union after generating its JSON Schema, which needed a conversion step and a reverse conversion of each call; building the keyed shape directly removes both, and a pruned list makes a write absent from both the schema and the parser.

### 4. Results and failures

A success is one text content holding the compact JSON of the SDK value, or `{"ok":true}` when the operation returns nothing.
`download` and `attach` of `redmine_attachments` answer a summary of the file instead of the content: the path written, filename, content type, and size for `download`, and the issue, filename, and size for `attach`.

A failure is one text content holding `{"status": <int>, "errors": [<string>]}` with `isError: true`, filled as the table below shows for each kind of failure.

| Failure                                          | `status`        | `errors`                                        |
| ------------------------------------------------ | --------------- | ----------------------------------------------- |
| Redmine answered non-2xx                         | the HTTP status | Redmine's `errors` array                        |
| Invalid arguments                                | `0`             | `invalid arguments: <action>.<field>: <reason>` |
| A local file error                               | `0`             | the file error's message                        |
| Redmine answered 2xx but the body was unreadable | `0`             | a message that says the server answered         |
| Redmine was not reached                          | `0`             | the transport's message                         |

#### Rationale

This is the payload denomine-mcp returns, and the `errors` array is Redmine's own validation messages, which is what lets a model correct a field.
The split between an unreadable answer and an unreachable Redmine, and why both keep status `0`, is the subject of ADR-023.

### 5. `redmoon_info` replaces `denomine_mcp_info`

It answers `{ "version": "<release>", "build": { "commit": "<sha>", "dirty": <bool> } }`, with `build` null when the server was built from source rather than as a release.
Its description says it describes the MCP server, not a Redmine version.

#### Rationale

The tool list is the only channel a model can query by itself, so a model can only report the build it is talking to through a tool.

### 6. `redmine_memberships` supplies the ids `assigned_to_id` takes

`list` takes `project_id` as an id or identifier and a `limit`, and follows every page when no `limit` is given.
It wraps `GET /projects/:project_id/memberships.json`, which lists every user and group that is a member of a project together with their roles.
Each membership keeps the principal under Redmine's own key, `user`, `group`, `group_anonymous`, or `group_non_member`, rather than a shared `principal` member.

The tool description states that the id to pass to `assigned_to_id` is `user.id` or `group.id`, not the membership's own `id`.
It also states that a listed principal is assignable only when one of its roles allows assignment, that a group additionally needs Redmine's "Allow issue assignment to groups" setting, and that the built-in groups cannot be assigned.
The `assigned_to_id` descriptions of `redmine_issues` point to this tool.

#### Rationale

The endpoint is gated by the `view_members` permission, which Redmine declares public and read-only, so an ordinary member can call it.
`/users.json` and `/groups.json` were rejected because Redmine restricts them to administrators.
Adding a read-only tool removes no behaviour while filling a gap that blocked a common request, and since its only action reads, `--readonly` keeps it.
Keeping Redmine's keys means the response carries the same names as Redmine's documentation, and a model reading `group.id` passes the right number.
The membership `id` is the first number a model sees, so the description has to rule it out explicitly.

### 7. Free-text fields can be read from a local file

Each long free-text field has a `_path` sibling naming a local file: issue `description` on `create` and `update` takes `description_path`, issue `notes` on `update` and `update_note` takes `notes_path`, and wiki `text` on `create` and `update` takes `text_path`.

The rules below govern how a field and its file argument combine and how the file is read.

- Giving both a field and its file fails with status `0`; on `update_note` it fails as `update_note.notes_path: unknown field`, because that action picks its shape by key and `notes` is matched first.
- Wiki `text` needs exactly one of the two.
- The tool schema states each pairing with `oneOf` inside the action, and with `allOf` of one `oneOf` per pair on `update` of an issue.
- The file is sent as is, trailing newline included, except that a leading UTF-8 byte order mark is dropped.
- A file over 1 MiB or not valid UTF-8 is refused with status `0`.
- `update_note` refuses blank (empty or whitespace only) `notes`, whether inline or from `notes_path`.

#### Rationale

A path is short, and the model writes the text with tools built for files, so a long body no longer depends on JSON escaping.
A separate argument keeps each field a plain string instead of a string-or-object `anyOf`.
The limits stop a mistaken path from posting a binary or a log, a byte order mark would break the first line's markup, and blank notes would erase the comment, which `delete_note` exists for.

### 8. `show` can save the text to a local file

Issue `show` takes `description_path` and wiki `show` takes `text_path`.
The text is written there with `\r\n` turned into `\n`, and the response carries the absolute path written under that key instead of the text.
An existing file is never replaced, as for `download`.
Journal notes have no such argument.

#### Rationale

The model can save, edit only the changed parts, and send the same file back, without writing the whole body or reading it into its context.
Redmine stores an issue description's line breaks as `\r\n` whatever was sent, while wiki text is stored as sent; the model's edit tool matches `\n`, and since Redmine turns an issue description back into `\r\n`, the round trip leaves it unchanged.
One path cannot say which of an issue's many journals to save, and notes are usually short.

### 9. Files are read into the arguments before they are parsed

The arguments are first validated whole, then each `_path` file is read into its field, and the result is parsed into the same action a call without files produces.

#### Rationale

Parsing is synchronous and reading a file is not, so the text cannot be read while the action is built.
Reading it beforehand keeps the actions, handlers, and SDK requests unchanged, instead of carrying paths in the actions and rebuilding each request with the text.
Validating first reports a mistaken argument without touching the filesystem.

### 10. Text is not edited on the server

A `description_edits` argument of old and new strings was rejected.
Redmine has no partial update of a text field, so redmoon would read and write back the whole text and lose a change made in between, and it would repeat what the client's edit tool already does.

### 11. The download limit `max_size` is an `Int64`

`download` of `redmine_attachments` refuses an attachment larger than `max_size`, which defaults to 500 MiB.
The SDK reports an attachment's size as a `ByteSize` and sets no limit of its own ([ADR-026](./adr-026-typed-redmine-sdk.md)), so the limit belongs to redmoon.

`omochice/schema` offers `integer64(min?, max?) -> Schema[Int64]`, which reads a JSON number, advertises `"type": "integer"`, and writes its bounds as numbers.
redmoon parses `max_size` with it.
`optional_or` advertises its default with the value's `ToJson`, which for `Int64` would be a string, so redmoon wraps the limit in a private newtype, `ByteLimit`, whose `ToJson` writes a number.

#### Rationale

Redmine stores attachment sizes as a `bigint`, and an attachment that can be read could still never be downloaded while the limit stayed below 2 GiB.
The limit is redmoon's decision rather than a size Redmine reports, so it does not reuse the SDK's `ByteSize`.
The newtype keeps the workaround for core's `Int64` encoding inside redmoon, so `omochice/schema` gains only the integer schema and `optional_or` keeps its meaning for every other caller.

## Consequences

### Positive

1. **Same capabilities as denomine-mcp**: every action of denomine-mcp is reachable, in both modes.
2. **One naming scheme end to end**: no key is renamed between Redmine and the model.
3. **Group and user ids are discoverable** without administrator rights.

### Negative

1. **Not a drop-in replacement for denomine-mcp**: a prompt or script written against its camelCase arguments fails against redmoon, and a prompt written for redmoon can call `redmine_memberships` or a `_path` argument that denomine-mcp lacks.
2. **Fields outside the SDK types are dropped**: a field Redmine or a plugin returns that the SDK does not model is absent from the response.
3. **Listing does not prove assignability**: Redmine decides assignability from role and setting data that the memberships response does not include.
4. **The server and the model's tools have to share a filesystem** for the `_path` arguments to work.
5. **`description_path` is read in `create` and `update` but written in `show`.**

### Mitigations

- Arguments are strict objects, so a camelCase name is rejected with `invalid arguments: <action>.<field>: unknown field` rather than ignored, and the model learns the right name from the error and the schema.
- The SDK types follow Redmine's REST API documentation for each resource, including custom fields, which are part of Redmine itself; a missing field is added to the SDK when it is noticed.
- The memberships description names the conditions under which a listed principal can be assigned, so a model can explain a rejected assignment from Redmine's validation error.
- The inline string arguments remain for a setup where the server and the model do not share a filesystem.
- Each `_path` argument's description says whether the file is read or written.

## Implementation Notes

A relative `_path` resolves against the working directory of the server process, so every path description recommends an absolute path.

## References

- [ADR-005](./adr-005-tool-surface.md), [ADR-019](./adr-019-design-evolution-from-adr-005.md), and [ADR-021](./adr-021-design-evolution-from-adr-005.md) — the records this ADR consolidates and supersedes.
- [denomine-mcp ADRs](https://github.com/Omochice/denomine-mcp/tree/main/doc/adr) — ADR-0001, 0002, 0012, 0015, 0016, 0017.
- [ADR-003](./adr-003-typed-schema-dsl.md) and [ADR-011](./adr-011-design-evolution-from-adr-003.md) — the schema DSL `keyed` and `integer64` belong to and the record builder each action uses.
- [ADR-026](./adr-026-typed-redmine-sdk.md) — the typed values the tools return.
- [ADR-007](./adr-007-error-handling.md) and [ADR-023](./adr-023-design-evolution-from-adr-007.md) — how failures reach the payload.
- [ADR-017](./adr-017-redmine-plugin-sdk-module.md), [ADR-025](./adr-025-redmineup-agile-data.md), and [ADR-030](./adr-030-additional-tags-issue-tags.md) — the plugin tools and the `--plugin` option that enables them.
- [Redmine REST API: Memberships](https://www.redmine.org/projects/redmine/wiki/Rest_Memberships) — the endpoint `redmine_memberships` wraps.
- [Redmine REST API: Issues](https://www.redmine.org/projects/redmine/wiki/Rest_Issues) and [Wiki Pages](https://www.redmine.org/projects/redmine/wiki/Rest_WikiPages) — text fields are sent whole on `PUT`.
- [redmine/redmine `lib/redmine/preparation.rb`](https://github.com/redmine/redmine/blob/master/lib/redmine/preparation.rb) — the `view_members` permission.
- [redmine/redmine `app/controllers/users_controller.rb`](https://github.com/redmine/redmine/blob/master/app/controllers/users_controller.rb) and [`groups_controller.rb`](https://github.com/redmine/redmine/blob/master/app/controllers/groups_controller.rb) — `require_admin` on every action but `show`, which rules out `index`.
- [redmine/redmine `app/models/project.rb`](https://github.com/redmine/redmine/blob/master/app/models/project.rb) — `assignable_users`, which allows only `User` and, with the setting, `Group`.
