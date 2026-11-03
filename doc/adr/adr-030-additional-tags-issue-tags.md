# ADR-030: Issue Tags of Additional Tags as a Third Plugin Package, Edited by Adding and Removing Names

## Status

Accepted

## Context

Redmine itself has no tags.
Instances that tag issues get the tags from a plugin, and the AlphaNodes Additional Tags plugin is the open-source one in current use.
`redmine_issues` cannot read or write them, so a model asked to tag an issue, or to find the issues that carry a tag, cannot do it.

[ADR-017](./adr-017-redmine-plugin-sdk-module.md) put the API of the redmine_issue_templates plugin into `omochice/redmine-plugins`, and [ADR-025](./adr-025-redmineup-agile-data.md) added RedmineUP Agile there as a second package with a tool of its own.

The plugin's README does not describe its REST API, so the shapes below were read from its source and its API tests and then observed on the verification Redmine.
The verification Redmine ran Redmine 7.0.2 with additionals and additional_tags at their 4.6.0 tags; additional_tags refuses to load without additionals.
The observations were made on 2026-11-03 as the administrator and as the seeded member `redmoon-member`, whose Developer role was given and denied each tag permission in turn.

| Request                                                      | What was observed                                                                                                                                                                  |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /issues/:id.json`                                       | `issue.tags` is `[{"id": 1, "name": "alpha"}, ...]` without any `include`; the key is absent while issue tags are off or without `view_issue_tags`                                 |
| `GET /issues.json`                                           | no `tags` key on any issue                                                                                                                                                         |
| `PUT /issues/:id.json` with `{"issue": {"tag_list": [...]}}` | `204`, and the issue's tags are replaced by the list; `[]` and `""` remove every tag                                                                                               |
| a `tag_list` name with surrounding spaces or another case    | the spaces are dropped and the name joins the existing tag of the same name in any case, so `"  Alpha  "` becomes `alpha`                                                          |
| a `tag_list` name containing a comma                         | `"a,b"` becomes the two tags `a` and `b`                                                                                                                                           |
| `GET /issues.json?f[]=tags&op[tags]==&v[tags][]=alpha`       | the issues tagged `alpha`, matched in any case; several values match an issue carrying any of them; `?tags=alpha` filters the same                                                 |
| `GET /issues.json?tag_id=9`                                  | the issues tagged with that id; a tag no issue carries any more is deleted, and the same name created again gets a new id                                                          |
| `GET /additional_tags.json?type=issue`                       | `{"tags": [{"id": 9, "name": "alpha", "count": 1}], "total_count": 1, "tag_type": "Issue"}` for the administrator, `403` with an empty body for a member with every tag permission |
| `GET /additional_tags.json`                                  | `422` with `{"errors": ["Tag type is not provided or not supported"]}`                                                                                                             |
| `GET /auto_completes/issue_tags`                             | `[]` with any API key, because the action does not accept API authentication                                                                                                       |

The plugin declares three permissions in the issue tracking module: `view_issue_tags`, `edit_issue_tags`, and `create_issue_tags`.
When a write is not allowed, the plugin drops the whole `tag_list` and saves the rest of the update, and Redmine still answers `204`.

| Caller's permissions                      | `tag_list` sent                          | Result                     |
| ----------------------------------------- | ---------------------------------------- | -------------------------- |
| all three                                 | names that do not exist yet              | saved                      |
| `view_issue_tags`, `edit_issue_tags`      | `["alpha", "gamma"]`, both existing      | saved                      |
| `view_issue_tags`, `edit_issue_tags`      | `["alpha", "brandnew"]`                  | dropped, `subject` saved   |
| `view_issue_tags`, `edit_issue_tags`      | `"alpha, Beta Tag"`, both existing       | dropped                    |
| `view_issue_tags`, `edit_issue_tags`      | `["ALPHA", "gamma"]`, `alpha` existing   | dropped                    |
| `view_issue_tags`                         | any                                      | dropped                    |

The comma string is dropped because the plugin checks the permission against the elements of `tag_list` before it splits them at commas, so it looks up the whole string as one tag name.
The plugin saves no tag at all until its `active_issue_tags` setting is switched on.

RedmineUP also distributes a Tags plugin.
It is free but closed, downloaded through an e-mail form, and its REST API is mentioned only in a changelog line, so nothing could be measured or built against it.

## Decision Drivers

- **A model adds and removes one tag at a time**: tagging is an incidental step of other work, and the model should not have to restate the tags it is not changing.
- **No silent loss**: a write the plugin drops must not be reported as a success.
- **One role per unit and opt-in per instance**, as [ADR-017](./adr-017-redmine-plugin-sdk-module.md) and [ADR-025](./adr-025-redmineup-agile-data.md) decided for the earlier plugins.

## Considered Options

### Option 1: `tag_list` spliced into `redmine_issues`

```json
{"update": {"id": 42, "tag_list": ["bug", "ui"]}}
```

#### Pros

- One call changes an issue and its tags.

#### Cons

- ADR-025 rejected the same shape for agile data: `redmine_issues` would describe a field most instances do not have, or change its schema with `--plugin`.
- A dropped `tag_list` would turn an otherwise successful issue update into a failure, or be hidden inside it.

### Option 2: A `redmine_tags` tool whose write is the plugin's replacement

```json
{"set": {"issue_id": 42, "tags": ["bug", "ui"]}}
```

#### Pros

- One request per write, and nothing is lost between a read and the write.

#### Cons

- To add one tag the model has to read the issue, copy every tag, and send them back, and a tag it forgets is removed.

### Option 3: A `redmine_tags` tool that adds and removes names (chosen)

```json
{"add": {"issue_id": 42, "tags": ["needs-review"]}}
```

#### Pros

- The model names only the tags it changes.

#### Cons

- Each write reads the tags first, so a change made between the read and the write is lost.

## Decision

We will add `additional_tags` as the third package of `omochice/redmine-plugins` and a `redmine_tags` tool over it that `serve --plugin additional_tags` registers.

### 1. `redmine_tags`, enabled by `serve --plugin additional_tags`

```json
"args": ["serve", "--endpoint", "https://redmine.example.com", "--plugin", "additional_tags"]
```

| Tool           | Actions                                        | Write actions   | Enabled by                 |
| -------------- | ---------------------------------------------- | --------------- | -------------------------- |
| `redmine_tags` | `show`, `add`, `remove`, `list`, `list_issues` | `add`, `remove` | `--plugin additional_tags` |

- `show` takes `issue_id` and answers the issue's tag names.
- `add` and `remove` take `issue_id` and `tags`, a non-empty array of names, and answer the issue's tag names after the write.
- `list` takes no argument and answers every issue tag with its name and the number of issues that carry it.
- `list_issues` takes `tags`, a non-empty array of names, with the optional `project_id`, `status_id`, and `limit` of `redmine_issues` `list`, and answers the issues carrying any of the names.

`--readonly` drops `add` and `remove` as it drops the write actions of the other tools ([ADR-028](./adr-028-tool-surface.md)).
The description says that the tool needs the Additional Tags plugin with issue tags switched on, names the three permissions, and says that `list` needs an administrator.

#### Rationale

The opt-in follows ADR-017 and ADR-025, because redmoon cannot tell which plugins an instance runs.
The value names the plugin rather than tags in general, so RedmineUP Tags can be given a value of its own if it is ever supported; it is left out now because there is nothing public to build its types on.
The actions follow the names of [ADR-028](./adr-028-tool-surface.md): `show` reads one thing as in every core tool, and a second listing in one tool is `list_<thing>` as `list_queries` is in `redmine_issues`.
`redmine_agile` names its read `get`, but one plugin tool was not reason enough to depart from the rest.
`add` and `remove` were chosen over `create` and `delete`, which the other tools keep for a resource with an id of its own, because a tag is attached to an issue and detached from it rather than created and deleted.
`list` is kept although it serves only administrators, because it is the only listing the plugin offers over the API.
`list_issues` is part of this tool rather than a filter of `redmine_issues` for the same reason as Option 1.

### 2. A 403 from `list` says that an administrator is needed

A `403` with an empty body from `list` is returned with status `403` and the single error `the tag list needs a Redmine administrator, and the API key may belong to a user who is not one`.

#### Rationale

Redmine sends this `403` with an empty body, so the usual failure would be `{"status": 403, "errors": []}`, which a model cannot tell from a project or permission problem.
The plugin's controller rejects every non-administrator before it looks at any permission, so a `403` here has only one cause, and naming it lets the model stop retrying and fall back to `show`.
Replacing the message is limited to `list`, because a `403` elsewhere can come from several permissions and Redmine's own errors are kept there.

### 3. `add` and `remove` read, merge, and replace

#### Change from

No client for the plugin.

#### Change to

```moonbit
pub async fn tags(Redmine, issue_id : Int32) -> Array[String] raise RedmineError

pub async fn add(Redmine, issue_id : Int32, Array[String]) -> Array[String] raise RedmineError

pub async fn remove(Redmine, issue_id : Int32, Array[String]) -> Array[String] raise RedmineError
```

`add` reads the issue's tags, appends each requested name that the issue does not carry in any case, and sends the result as `{"issue": {"tag_list": [...]}}`.
`remove` reads the tags and sends those whose names match none of the requested names in any case.
When the merge leaves the tags unchanged, nothing is written, so removing a tag the issue does not carry succeeds without a request.

#### Rationale

The plugin offers only replacement, so the merge has to happen somewhere, and placing it in the package keeps every consumer of the SDK from repeating it.
Matching in any case mirrors the plugin, which treats `Alpha` and `alpha` as one tag, so `add` does not send a duplicate that the plugin would fold away and `remove` does not miss a tag that differs only in case.
Skipping an unchanged write keeps a no-op from adding an empty journal to the issue.

### 4. Every write is read back

After a write, `add` and `remove` read the tags again.
If an added name is missing or a removed name is still present, the call fails with status `0` and a message saying that Redmine accepted the update without saving the tags, which happens without `edit_issue_tags`, without `create_issue_tags` for a new name, or while the plugin's issue tags are off.
`show`, and the reads inside `add` and `remove`, fail the same way when the answer carries no `tags` key.

#### Rationale

The plugin answers `204` for a dropped `tag_list`, so the answer to the write cannot tell a saved list from a dropped one, and only a second read can.
Reporting it follows ADR-025's rule that a failure with a remedy is not swallowed.
Status `0` is used because Redmine's own status was a success, and ADR-028 keeps `0` for failures that carry no Redmine status.
The SDK raises it as `Decode`, the error [ADR-023](./adr-023-design-evolution-from-adr-007.md) gives a 2xx answer that cannot be used, but its message starts with what Redmine did rather than with ADR-023's sentence that the answer could not be read, because here the answer was read and it is its content that is wrong.

### 5. `tag_list` is an array of validated names

Names are sent as a JSON array, never as a comma-separated string.
A name that is empty after trimming, or that contains a comma, is rejected as an invalid argument with status `0` before any request, and so is an empty array of names.

#### Rationale

The plugin rejects a comma string from a user without `create_issue_tags` even when every tag exists, and accepts the same names as an array.
A comma inside a name would be split into several tags, so the tag the model asked for would never exist, and rejecting it up front gives the model the reason instead of a read-back failure.

### 6. Issues are found by tag name

`list_issues` sends `set_filter=1&f[]=tags&op[tags]==` with one `v[tags][]` per name.
The status goes in as a filter of its own, `f[]=status_id` with `op[status_id]` set to `o`, `c`, or `*`, or to `=` with `v[status_id][]` for one status, and open issues are asked for when no status is given; the project goes in as `project_id`.

#### Rationale

For the status: once `f[]` is given, Redmine ignores the `status_id` shorthand that `redmine_issues` sends and lists issues of every status, which was observed with an open and a closed issue carrying the same tag.
Defaulting to open issues keeps `list_issues` answering what `list` of `redmine_issues` answers for the same status argument.

#### Rationale

Names are what a model reads in `show` and writes in `add`, while a tag's id is not stable, because the plugin deletes a tag no issue carries and gives the same name a new id when it is used again.
`tag_id` would also need the id from `list`, which members cannot call.
The explicit filter form was chosen over the `tags=` shorthand because it states the operator, and several names match any of them as a model asking for "issues tagged A or B" expects.

The request goes through `@redmine.send`, paged by a copy of the paging helper of `omochice/redmine` kept in `redmine-plugins/src/internal/paging`, and each issue is decoded into `@issues.Issue`.

#### Rationale

[ADR-017](./adr-017-redmine-plugin-sdk-module.md) has plugin packages reach Redmine only through `@redmine.send` and repeat the helpers they need, because widening `omochice/redmine`'s public surface to share them was rejected.
Opening the `Selection` trait of `@issues.list` to other modules was rejected for the same reason: it would let code outside `omochice/redmine` put parameters into a core request, which the trait is sealed to prevent.
`@issues.Issue` is a public type and decoding into it sends nothing, so `list_issues` answers in the same shape as `list` of `redmine_issues` without touching how the plugin reaches Redmine.

### 7. The verification Redmine installs both plugins at 4.6.0

`docker/redmine/Dockerfile` pins additionals and additional_tags to the commits of their 4.6.0 tags, and `task redmine:seed` switches issue tags on and gives the Developer role `view_issue_tags` and `edit_issue_tags` but not `create_issue_tags`, so the member can attach an existing tag and has a new one dropped.
`task redmine:seed` also saves the API key of `redmoon-member` beside the administrator's, and `task test:integration` passes it as `REDMOON_TEST_MEMBER_API_KEY`.
A second member, `redmoon-tagger`, holds a role that may also create tags, and its key is passed as `REDMOON_TEST_TAGGER_API_KEY`.

#### Rationale

Unlike RedmineUP Agile, the plugin can be installed from its repository, so its shapes are measured and covered by live tests rather than taken from a third party.
The 4.6.0 tags are the latest release of both plugins, and an installation normally takes a release rather than the main branch, so the tests follow what users run.
The behaviours that most need a live test, the dropped write and the `403` of `list`, happen only to a user who is not an administrator, so the tests need a member key, and a new tag saved for a member needs a second member who may create tags.

## Consequences

### Positive

1. **Tags become reachable**: a model can tag an issue, untag it, and find the issues that carry a tag.
2. **Dropped writes are visible**: a missing permission or a switched-off setting is reported instead of looking like success.
3. **Measured shapes**: the types follow answers observed on a running instance, and live tests keep checking them.
4. **The plugin stays opt-in**: instances without it see no new tool.

### Negative

1. **Three requests per changing write, without a lock**: a tag changed by someone else between the read and the write is overwritten.
2. **No catalogue for members**: `list` answers 403 to anyone but an administrator, so a member cannot discover the tags in use.
3. **A differently cased existing name is dropped for a member without `create_issue_tags`**: the plugin rejects it, so `add` fails although the tag exists.
4. **Case is folded for ASCII letters only**: MoonBit's `String::to_lower` leaves other letters as they are, so `Ärger` and `ärger` are merged as two names while the plugin may store one, and the read-back then fails.
5. **`list_issues` returns no tags**: the issue listing does not carry them, so each issue's tags need a `show`.
6. **The verification Redmine lags the plugins' main branches**: a change to the API on main is not seen until it is released.
7. **A second paging helper**: a fix to the paging of `omochice/redmine` has to be repeated in `omochice/redmine-plugins`.
8. **Wiki tags stay unreachable**: the plugin also tags wiki pages, and this decision covers issues only.

### Mitigations

- The window between the read and the write is one round trip, and the read-back reports a lost addition or a returned removal.
- The description of `list` says it needs an administrator, its `403` names the missing administrator rights, and the description of `add` says to reuse names as `show` returns them; a member can also learn the names in use from `show` on related issues.
- The read-back failure names `create_issue_tags` as one cause, which tells a model to retry with the existing name's case or ask for the permission.
- The read-back reports a name lost to a non-ASCII case mismatch rather than letting it pass, and names in scripts without case, such as Japanese, are not affected, so a Unicode case table is left for when one is needed.
- `show` takes one request per issue and is cheap to call for the issues a listing returns.
- The pins are commit hashes of tags, so moving to the next release is one reviewable change.
- The copy is small and covered by the live test of `list_issues`, which ADR-017 already accepted for `internal/decode`.
- Wiki tags follow in a pull request of their own, once their API has been measured; [ADR-031](./adr-031-additional-tags-wiki-page-search.md) records what that measurement allowed.

## Implementation Notes

- The merge in `add` and `remove` is a pure function from the current names and the requested names to the list to send, or to nothing, so it is unit-tested without a Redmine.
- The read of one issue's tags decodes only `issue.tags` from `GET /issues/:id.json`, so it does not depend on how `@issues.Issue` decodes the rest of the issue.
- The live tests create their own issue and delete it, and put the Developer role's permissions back when they change them, so the seeded state stays the same for the other tests.
- [ADR-028](./adr-028-tool-surface.md) lists every tool, so its table gains the `redmine_tags` row.

## References

- [ADR-017](./adr-017-redmine-plugin-sdk-module.md) — the plugin module and the `--plugin` option.
- [ADR-025](./adr-025-redmineup-agile-data.md) — the second plugin package, the carry-forward write, and the rule that failures are not swallowed.
- [ADR-028](./adr-028-tool-surface.md) — the tool surface, `--readonly`, and the failure payload.
- [AlphaNodes/additional_tags](https://github.com/AlphaNodes/additional_tags) — at tag `4.6.0`, commit `3d503b183ae9254d89bc8f71a517f1f3ec1662c4`; `lib/additional_tags/patches/issue_patch.rb` drops a disallowed `tag_list`, `lib/additional_tags/patches/issue_query_patch.rb` defines the `tags` filter, and `app/controllers/additional_tags_controller.rb` requires an administrator.
- [AlphaNodes/additionals](https://github.com/AlphaNodes/additionals) — at tag `4.6.0`, commit `5f5ff955dcff00e5fef47c7609f9e0d4fb038178`, required by additional_tags.
- [RedmineUP Tags](https://www.redmineup.com/pages/plugins/tags) — the closed alternative left out of scope.
