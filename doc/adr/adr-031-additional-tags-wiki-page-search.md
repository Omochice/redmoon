# ADR-031: Wiki Pages of Additional Tags Found by Tag, Without Writing Their Tags

## Status

Accepted

## Context

[ADR-030](./adr-030-additional-tags-issue-tags.md) gave `redmine_tags` the issue tags of the Additional Tags plugin and left its wiki page tags for later, once their API had been measured.

The wiki page tags were observed on 2026-11-03 on the verification Redmine, Redmine 7.0.2 with additional_tags 4.6.0, as the administrator and as the seeded member.

| Request                                                                 | What was observed                                                                                                          |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `GET /projects/demo/wiki/:title.json`, with or without `include=tags`   | no `tags` key; the plugin has no API view for a wiki page                                                                  |
| `GET /projects/demo/wiki/index.json?tag=wtag`                           | `{"wiki_pages": [...]}` with only the pages tagged `wtag`, matched in any case, for the administrator and the member alike |
| the same request while the plugin's `active_wiki_tags` is off           | every page of the wiki, as without `tag`                                                                                   |
| `GET /projects/demo/wiki/index.json?tag=redmoon,none` while tags are on | `{"wiki_pages": []}`                                                                                                       |
| `PUT /projects/demo/wiki/:title.json` with only `tag_list`              | `422` with `{"errors": ["Text field cannot be blank"]}`                                                                    |
| the same with the page's current `text`                                 | `204`, the tags replaced and the version unchanged; with a stale `version` and changed text, `409`                         |
| `PUT /projects/demo/wiki/:title/update_tags.json`                       | `403` with any API key, because the action does not accept API authentication                                              |
| `GET /additional_tags.json?type=wiki`, or `wiki_page`                   | `422`, because the plugin looks the type up as the class `Wiki`, which has no tags                                         |

The plugin's wiki controller patch falls back to Redmine's own index whenever `active_wiki_tags` is off or `tag` is empty, which is why a switched-off setting answers every page.
A plugin that is not installed answers the same way, since Redmine's index ignores `tag`.
Writing a tag takes the `add_wiki_tags` permission of the wiki module.

## Decision Drivers

- **No silent loss**: as in ADR-030, a model must not destroy tags it was not asked to touch, nor be told a search succeeded when the filter was ignored.
- **One tool for the plugin**: wiki tags belong to the same plugin and the same `--plugin additional_tags` value as issue tags.

## Considered Options

### Option 1: `add` and `remove` for wiki pages, as for issues

#### Pros

- A model would handle both kinds of tags the same way.

#### Cons

- Adding and removing need the page's current tags, and no request a member or an administrator can make answers them, so there is nothing to merge with.

### Option 2: A replacing `set_wiki_tags`

```json
{"set_wiki_tags": {"project_id": "demo", "title": "Guide", "tags": ["howto"]}}
```

#### Pros

- The write itself works, with the page's text and version sent back unchanged.

#### Cons

- The model cannot see which tags it would remove, so a call meant to add one tag erases the others.
- The result cannot be read back except by searching for each name, which shows added names but not that a removed one is gone.

### Option 3: Searching only (chosen)

```json
{"list_wiki_pages": {"project_id": "demo", "tag": "howto"}}
```

#### Pros

- It is the one wiki tag operation the plugin answers fully and to members.

#### Cons

- Wiki tags are read-only through redmoon.

## Decision

We will add a `list_wiki_pages` action to `redmine_tags` that lists the wiki pages of one project carrying one tag, and nothing that writes wiki tags.

### 1. `list_wiki_pages` takes one project and one name

| Tool           | Actions added      | Write actions added | Enabled by                 |
| -------------- | ------------------ | ------------------- | -------------------------- |
| `redmine_tags` | `list_wiki_pages`  | none                | `--plugin additional_tags` |

It takes `project_id`, an id or identifier as `redmine_wiki_pages` takes it, and `tag`, a name validated as in ADR-030, and answers the pages in the shape `list` of `redmine_wiki_pages` answers.
`--readonly` keeps it.

#### Rationale

The plugin filters the index by one name at a time, so a single name is what the request can express, and several names would need one request each and a merge the plugin does not define.
The answer reuses `@wiki.PageSummary`, so a model can pass a title from it straight to `show` of `redmine_wiki_pages`.

### 2. A name no tag can have proves the filter ran

Before the real search, the SDK lists the same index with `tag=redmoon,none`.
If that answers any page, the call fails with status `0` and a message saying that the plugin is not installed or its wiki tags are switched off.

#### Rationale

A filter that is ignored answers every page, which would tell the model that every page carries the tag.
The plugin splits names at commas, so no page can carry a name containing one, and an answer with any page can only come from an index that ignored `tag`.
A project without wiki pages answers nothing either way, and then the real search answers nothing as well, so the probe's blind spot never produces a wrong answer.
The failure is raised as `Decode`, as ADR-030 raises a dropped write: Redmine answered 2xx, and it is the content that cannot be used.

### 3. Writing wiki tags is left out

#### Rationale

Option 2 is the only write the API allows, and its cost, removing tags the model cannot see, is the loss ADR-030 was designed to avoid.
If the plugin later answers a page's tags, `add` and `remove` for pages can be built on the generic merge and read-back of the `additional_tags` package.

## Consequences

### Positive

1. **Wiki pages become findable by tag**, for members as well as administrators.
2. **A switched-off or missing plugin is reported** instead of answering every page.

### Negative

1. **Two requests per search**: the probe doubles the requests of every call.
2. **Wiki tags cannot be read or changed**: a page's own tags are invisible through the API.
3. **One name per search**: pages carrying any of several names need several calls.

### Mitigations

- The probe and the search each list one project's index, which Redmine answers without paging.
- The description says that a page's tags cannot be read and that several names need several calls.

## Implementation Notes

- The seed switches `active_wiki_tags` on, and the live test tags a page by sending its text with `tag_list` as the administrator, then deletes it.
- The probe name is a constant of the package, so a test can assert that it was requested first.

## References

- [ADR-030](./adr-030-additional-tags-issue-tags.md) — the issue tags, the tool, and the failure shapes this ADR reuses.
- [ADR-028](./adr-028-tool-surface.md) — the tool table that gains the action.
- [AlphaNodes/additional_tags](https://github.com/AlphaNodes/additional_tags) — at tag `4.6.0`; `lib/additional_tags/patches/wiki_controller_patch.rb` falls back to Redmine's index and defines `update_tags`, and `lib/additional_tags/patches/wiki_page_patch.rb` guards `tag_list` with `add_wiki_tags`.
