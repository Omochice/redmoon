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
- The file is sent as is, trailing newline included, except that a leading UTF-8 byte order mark is dropped.
- A file over 1 MiB or not valid UTF-8 is refused with status `0`, and so is a blank (empty or whitespace only) `notes_path` file on `update_note`, as an empty `notes` is.

Redmine stores an issue description's line breaks as `\r\n` whatever was sent, while wiki text is stored as sent.

**Rationale**: a path is short, and the model writes the text with tools built for files.
A separate argument keeps each field a plain string instead of a string-or-object `anyOf`.
The limits stop a mistaken path from posting a binary or a log, a byte order mark would break the first line's markup, and a blank notes file would erase the comment, which `delete_note` exists for.

### 2. `show` can save the text to a local file

**Original Design (ADR-005)**: `show` returns every field.

**Revised Design**: issue `show` takes `description_path` and wiki `show` takes `text_path`.
The text is written there with `\r\n` turned into `\n`, and the response carries the written path under that key instead of the text.
An existing file is never replaced, and `--readonly` keeps the argument, as for `download`.
Journal notes have no such argument.

**Rationale**: the model can save, edit only the changed parts, and send the same file back, without writing the whole body or reading it into its context.
Its edit tool matches `\n`, and since Redmine turns an issue description back into `\r\n`, the round trip leaves it unchanged.
One path cannot say which of an issue's many journals to save, and notes are usually short.

### 3. Text is not edited on the server

A `description_edits` argument of old and new strings was rejected.
Redmine has no partial update of a text field, so redmoon would read and write back the whole text and lose a change made in between, and it would repeat what the client's edit tool already does.

### 4. The SDK request is copied, not opened

**Original Design (ADR-005)**: parsing builds the SDK request, such as `@issues.Create`, and the handler sends it unchanged.

**Revised Design**: parsing still builds the request, and the action carries the `_path` arguments beside it.
After reading the file, the handler rebuilds the request through `Create::new` or `Update::new`, replacing only the text.
The copy destructures the request with a pattern that names every field and omits `..`, so a field added to the SDK later fails `moon check --deny-warn` through `missing_pattern_field`.

**Rationale**: parsing is synchronous and reading a file is not, so the text is not available when the request is first built.
A method on the SDK type would widen its public API for one tool, and a builder closure in the action would hide the request from tests.

## Consequences

### Positive

1. **Long bodies no longer depend on JSON escaping.**
2. **Small edits to large bodies stay small, and the body stays out of the context.**

### Negative

1. **The arguments no longer match denomine-mcp's.**
2. **The server and the model's tools must share a filesystem.**
3. **`description_path` is read in `create` and `update` but written in `show`.**

### Mitigations

- redmoon runs over stdio under the MCP client, and the string arguments remain for any other setup.
- Each argument's description says whether the file is read or written.

## References

- [ADR-005](./adr-005-tool-surface.md) — the tool surface this ADR refines.
- [ADR-019](./adr-019-design-evolution-from-adr-005.md) — the earlier refinement of the same surface.
- [Redmine REST API: Issues](https://www.redmine.org/projects/redmine/wiki/Rest_Issues) and [Wiki Pages](https://www.redmine.org/projects/redmine/wiki/Rest_WikiPages) — text fields are sent whole on `PUT`.
