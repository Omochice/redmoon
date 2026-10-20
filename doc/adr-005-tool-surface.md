# ADR-005: Tool Surface Carried Over from denomine-mcp in snake_case

## Status

Proposed

## Context

The behaviour redmoon has to satisfy is that of denomine-mcp.
Its tool surface was settled across several of its ADRs:

- One tool per Redmine resource, with an action selecting the operation, keeps the tool list short while every endpoint stays reachable (its ADR-0001).
- `--readonly` removes write actions from the schema, so a write is inexpressible rather than rejected (its ADR-0001).
- The advertised schema is keyed by action, `{ "<action>": { ...fields } }`, because the Anthropic Messages API answers HTTP 400 to an `input_schema` with `oneOf`, `anyOf`, or `allOf` at the top level, and one such tool fails every request (its ADR-0015).
- A success returns the payload as JSON text, and a failure returns `{ status, errors }` with `isError` (its ADR-0002).
- Attachments are downloaded to a local file and attached from one, never inlined (its ADR-0012 and ADR-0017).
- One tool reports the server's own version and build (its ADR-0016).

denomine-mcp names its arguments in camelCase (`projectId`, `statusId`) and returns camelCase keys, because `@omochice/redmine` converts Redmine's snake_case responses.
MoonBit names fields in snake_case, Redmine's JSON is snake_case, and redmoon's SDK returns typed values whose fields mirror that JSON ([ADR-006](./adr-006-typed-redmine-sdk.md)).

## Decision

We will expose the same tools, actions, and modes as denomine-mcp, with every argument and response key in snake_case.

### 1. The tools

| Tool                      | Actions                                                                                    | Write actions                          |
| ------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------- |
| `redmine_issues`          | `list`, `list_queries`, `show`, `create`, `update`, `delete`, `update_note`, `delete_note` | all but `list`, `list_queries`, `show` |
| `redmine_wiki_pages`      | `list`, `show`, `create`, `update`, `delete`                                               | `create`, `update`, `delete`           |
| `redmine_versions`        | `list`, `show`, `create`, `update`, `delete`                                               | `create`, `update`, `delete`           |
| `redmine_issue_relations` | `list`, `show`, `create`, `delete`                                                         | `create`, `delete`                     |
| `redmine_search`          | `search`                                                                                   | none                                   |
| `redmine_time_entries`    | `list`, `show`, `create`, `update`, `delete`                                               | `create`, `update`, `delete`           |
| `redmine_enumerations`    | `list_time_entry_activities`, `list_issue_priorities`, `list_document_categories`          | none                                   |
| `redmine_issue_templates` | `list`                                                                                     | none                                   |
| `redmine_attachments`     | `show`, `download`, `attach`                                                               | `attach`                               |
| `redmoon_info`            | `show`                                                                                     | none                                   |

Each tool keeps the arguments, constraints, defaults, and description text of its denomine-mcp counterpart, with names converted to snake_case.

**Rationale**: the tool list, the per-action shapes, and the descriptions are what a model sees, so keeping them is what keeps the behaviour.

### 2. snake_case arguments and responses

**Change from**: `{ "list": { "projectId": 1, "statusId": "open" } }` answered with `[{ "id": 1, "assignedTo": { ... } }]`

**Change to**: `{ "list": { "project_id": 1, "status_id": "open" } }` answered with `[{ "id": 1, "assigned_to": { ... } }]`

**Rationale**: a model reads `project_id` in a response and passes it back unchanged, and the same names hold from the Redmine wire through the SDK structs to the tool, so no layer renames anything.

### 3. The action-keyed schema is a combinator of `omochice/schema`

```moonbit
@schema.keyed([
  ("list", list_input.map(IssueInput::List)),
  ("show", show_input.map(IssueInput::Show)),
  ...
])
```

`keyed` emits `{ type: "object", properties: { <action>: <schema> }, minProperties: 1, maxProperties: 1, additionalProperties: false }` and parses into the tool's input enum.
An action spread over several shapes, such as `update_note`, is an `anyOf` inside its own property.
`--readonly` builds the list without the write actions.

**Rationale**: denomine-mcp re-keyed a discriminated union after generating its JSON Schema, which needed a conversion step and a reverse conversion of each call; building the keyed shape directly removes both, and a pruned list makes a write absent from both the schema and the parser.

### 4. Results and failures

A success is one text content holding the JSON of the SDK value, or `{"ok":true}` when the operation returns nothing.
A failure is one text content holding `{"status": <int>, "errors": [<string>]}` with `isError: true`; a failure with no HTTP status, such as invalid arguments or a local file error, has status `0`.

**Rationale**: this is the payload denomine-mcp returns, and the `errors` array is Redmine's own validation messages, which is what lets a model correct a field.

### 5. `redmoon_info` replaces `denomine_mcp_info`

It answers `{ "version": "<release>", "build": { "commit": "<sha>", "dirty": <bool> } }`, with `build` null when the commit is unknown.
Its description says it describes the MCP server, not a Redmine version.

**Rationale**: the tool list is the only channel a model can query by itself, so a model can only report the build it is talking to through a tool.

## Consequences

### Positive

1. **Same capabilities**: every action of denomine-mcp is reachable, in both modes.
2. **One naming scheme end to end**: no key is renamed between Redmine and the model.
3. **No conversion layer**: the advertised schema and the parser come from the same `keyed` value.

### Negative

1. **Not a drop-in replacement**: a prompt or script written against denomine-mcp's camelCase arguments fails against redmoon.
2. **Fields outside the SDK types are dropped**: a field Redmine or a plugin returns that the SDK does not model is absent from the response.

### Mitigations

- Arguments are strict objects, so a camelCase name is rejected with `<action>.<field>: unknown field` rather than ignored, and the model learns the right name from the error and the schema.
- The SDK types follow Redmine's REST API documentation for each resource, including custom fields, which are part of Redmine itself; a missing field is added to the SDK when it is noticed.

## References

- [denomine-mcp ADRs](https://github.com/Omochice/denomine-mcp/tree/main/doc/adr) — ADR-0001, 0002, 0012, 0015, 0016, 0017.
- [ADR-003](./adr-003-typed-schema-dsl.md) — the schema DSL `keyed` belongs to.
- [ADR-006](./adr-006-typed-redmine-sdk.md) — the typed values the tools return.
- [ADR-007](./adr-007-error-handling.md) — how failures reach the payload.
