# ADR-021: Design Evolution from ADR-005

## Status

Proposed

## Context

[ADR-005](./adr-005-tool-surface.md) passes every argument as a JSON value inside the tool call.
A model rewriting a large issue description sometimes emitted malformed JSON, because the whole body had to be escaped inside `{ "update": { "description": "..." } }`.
The same risk applies to `notes` and to wiki `text`.

redmoon runs over stdio beside the MCP client, and `redmine_attachments` already reads and writes local files.
The model also has its own tools to write a file and to replace an exact string in one.

## Design Changes from ADR-005

### 1. Free-text fields can be read from a local file

**Original Design (ADR-005)**: a free-text field is a JSON string only.

**Revised Design**: each long free-text field gets a `_path` sibling naming a local file.

| Tool                 | Actions                 | Field         | File argument      |
| -------------------- | ----------------------- | ------------- | ------------------ |
| `redmine_issues`     | `create`, `update`      | `description` | `description_path` |
| `redmine_issues`     | `update`, `update_note` | `notes`       | `notes_path`       |
| `redmine_wiki_pages` | `create`, `update`      | `text`        | `text_path`        |

- Giving both a field and its file fails with status `0`; on `update_note` it fails as `update_note.notes_path: unknown field`, because that action picks its shape by key.
- Wiki `text` needs exactly one of the two.
- The tool schema states each pairing with `oneOf` inside the action, and with `allOf` of one `oneOf` per pair on `update` of an issue.
- The file is sent as is, trailing newline included, except that a leading UTF-8 byte order mark is dropped.
- A file over 1 MiB or not valid UTF-8 is refused with status `0`.
- `update_note` refuses blank (empty or whitespace only) `notes`, whether inline or from `notes_path`.

Redmine stores an issue description's line breaks as `\r\n` whatever was sent, while wiki text is stored as sent.

**Rationale**: a path is short, and the model writes the text with tools built for files.
A separate argument keeps each field a plain string instead of a string-or-object `anyOf`.
The limits stop a mistaken path from posting a binary or a log, a byte order mark would break the first line's markup, and blank notes would erase the comment, which `delete_note` exists for.

### 2. Text is not edited on the server

A `description_edits` argument of old and new strings was rejected.
Redmine has no partial update of a text field, so redmoon would read and write back the whole text and lose a change made in between, and it would repeat what the client's edit tool already does.

### 3. Files are read into the arguments before they are parsed

**Original Design (ADR-005)**: the arguments are parsed into the tool's action, and the handler runs it.

**Revised Design**: the arguments are first validated whole, then each `_path` file is read into its field, and the result is parsed into the same action a call without files produces.

**Rationale**: parsing is synchronous and reading a file is not, so the text cannot be read while the action is built.
Reading it beforehand keeps the actions, handlers, and SDK requests unchanged, instead of carrying paths in the actions and rebuilding each request with the text.
Validating first reports a mistaken argument without touching the filesystem.

## Consequences

### Positive

1. **Long bodies no longer depend on JSON escaping.**

### Negative

1. **The arguments no longer match denomine-mcp's.**
2. **The server and the model's tools must share a filesystem.**

### Mitigations

- redmoon runs over stdio under the MCP client, and the string arguments remain for any other setup.

## References

- [ADR-005](./adr-005-tool-surface.md) — the tool surface this ADR refines.
- [ADR-019](./adr-019-design-evolution-from-adr-005.md) — the earlier refinement of the same surface.
- [Redmine REST API: Issues](https://www.redmine.org/projects/redmine/wiki/Rest_Issues) and [Wiki Pages](https://www.redmine.org/projects/redmine/wiki/Rest_WikiPages) — text fields are sent whole on `PUT`.
