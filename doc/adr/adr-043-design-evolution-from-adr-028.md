# ADR-043: Design Evolution from ADR-028

## Status

Accepted

## Context

[ADR-028](./adr-028-tool-surface.md) gave `redmine_attachments` an `attach` operation that sends a local file to an existing issue, and fixed its answer as the issue, filename, and size.

A model writing a wiki page had no way to embed an image, because no tool could attach a file to a wiki page.
Redmine accepts uploads on a wiki page through `wiki_page.uploads` on the same `PUT` that writes the page, but that request behaves differently from the issue update `attach` relied on.
Measured against Redmine 7.0.3, the wiki `PUT` behaves as follows.

- `text` cannot be left out, and a `PUT` to a missing page creates it.
- When `text` equals the current text, the uploads are attached, the version stays as it was, `comments` is dropped without an error, and `version` is not checked.
- When `text` differs and `version` is stale, Redmine answers 409 and attaches nothing.
- A shown page lists its attachments only when `include=attachments` is asked for.

This ADR records how `attach` reaches a wiki page within those constraints; every other decision of ADR-028 still holds as written.

## Design Changes from ADR-028

### 1. `attach` takes an issue or a wiki page as its target

#### Original Design (ADR-028)

`attach` takes `issue_id`, `path`, `filename`, `description`, and `notes`, and adds the file to that issue.

#### Revised Design

`attach` takes exactly one target, chosen by its key.
`issue_id` selects an issue and keeps the fields above.
`project_id` with `title` selects an existing wiki page and takes `path`, `filename`, and `description` only.
A mixed or partial target, and `notes` or `comments` on a wiki target, fail validation as an unknown or missing field.
One call sends one file, as before.

#### Rationale

The two targets are two closed records rather than one record with rules between optional fields, so the published schema is a plain choice of two objects that a model can read, and every invalid combination is rejected by the same `unknown field` and `is required` messages a model already learns from.
A wiki target accepts no comment because Redmine creates no version when the text is unchanged and drops the comment, so an accepted argument would have no effect.

### 2. A wiki page is attached to by sending its current text back

#### Original Design (ADR-028)

`attach` sends the uploads in an issue update, which needs no other field.

#### Revised Design

For a wiki target, the SDK shows the page, then sends the shown text and version back with the uploads.
A missing page fails with the 404 of the show.
A page edited between the show and the `PUT` fails with 409, which `attach` returns as a failure without retrying.

#### Rationale

Since the `PUT` needs the text and creates a missing page, sending the text unread would either fail or create a page the caller never asked for.
Sending the shown version makes an edit made in between fail instead of being reverted: that edit changed the text, so the text sent back differs and Redmine checks the version.
A retry would hide the conflict from the model, which can call `attach` again once it has seen the failure.

### 3. The answer for a wiki target names the page

#### Original Design (ADR-028)

`attach` answers the issue, filename, and size.

#### Revised Design

For a wiki target, `attach` answers `project_id` as the caller gave it, `title`, `filename`, and `filesize`.
The issue answer is unchanged.

#### Rationale

`project_id` is echoed in the form it was given, a number or an identifier, so the answer can be passed straight back to `redmine_wiki_pages`, where the model updates the page text to reference the file by its filename.

### Not Decided Here

Sending several files in one call is left open, for issues and wiki pages alike, until a model is seen to need it.

## Consequences

### Positive

1. **A model can embed an image in a wiki page** with `attach` followed by a text update in `redmine_wiki_pages`.
2. **A concurrent edit is never reverted**: it surfaces as 409 instead.

### Negative

1. **A wiki attach costs two requests**, the show and the `PUT`.
2. **A page deleted between the show and the `PUT` is recreated** with the text it had, because Redmine creates a page on `PUT`.
3. **The interface `redmine_attachments` reaches Redmine through gains an operation**, so any other implementation of it must add one.

### Mitigations

- The extra request is made only for a wiki target, so attaching to an issue costs what it did before.
- An implementation that lacks the new operation fails to compile, so the gap cannot reach a running server.
- The window between the two requests is short, and a recreated page holds the text it had before deletion, so nothing written is lost; guarding against it would need a request Redmine does not offer.

## References

- [ADR-028](./adr-028-tool-surface.md) — the decision this ADR refines.
- [Redmine REST API: Wiki Pages](https://www.redmine.org/projects/redmine/wiki/Rest_WikiPages) — `uploads` on `PUT` and `include=attachments` on `GET`.
