# ADR-019: Design Evolution from ADR-005

## Status

Proposed

## Context

[ADR-005](./adr-005-tool-surface.md) decided that redmoon exposes exactly the tools, actions, and modes of denomine-mcp.
In use, a model asked to create an issue and assign it to a group could not find the group's id.
`assigned_to_id` takes the id of a user or a group, and no tool in that surface lists the users or groups of a project.
The only way to learn such an id was to find an existing issue already assigned to the principal, which fails for a principal that has never been assigned anything.

Redmine answers this question with `GET /projects/:project_id/memberships.json`, which lists every user and group that is a member of a project together with their roles.
It is gated by the `view_members` permission, which Redmine declares public and read-only, so an ordinary member can call it.
`/users.json` and `/groups.json` were not chosen because Redmine restricts them to administrators.

This ADR records the departure from strict parity with denomine-mcp so that the reason for the extra tool stays visible.

## Design Changes from ADR-005

### 1. A `redmine_memberships` tool beyond denomine-mcp's surface

**Original Design (ADR-005)**: the tool list is exactly that of denomine-mcp.

**Revised Design**: one tool is added.

| Tool                  | Actions | Write actions |
| --------------------- | ------- | ------------- |
| `redmine_memberships` | `list`  | none          |

`list` takes `project_id` as an id or identifier and an optional `limit`, and follows every page by default.
Each membership keeps the principal under Redmine's own key, `user`, `group`, `group_anonymous`, or `group_non_member`, rather than a shared `principal` member.
The tool description states that the id to pass to `assigned_to_id` is `user.id` or `group.id`, not the membership's own `id`.
It also states that a listed principal is assignable only when one of its roles allows assignment, that a group additionally needs Redmine's "Allow issue assignment to groups" setting, and that the built-in groups cannot be assigned.
The `assigned_to_id` descriptions of `redmine_issues` point to this tool.

**Rationale**: parity was chosen to keep the behaviour models already relied on, and adding a read-only tool removes no behaviour while filling a gap that blocked a common request.
Keeping Redmine's keys means the response carries the same names as Redmine's documentation, and a model reading `group.id` passes the right number.
The membership `id` is the first number a model sees, so the description has to rule it out explicitly.

## Consequences

### Positive

1. **Group and user ids are discoverable** without administrator rights.
2. **The `--readonly` mode gains the tool too**, since its only action reads.

### Negative

1. **The tool list no longer matches denomine-mcp's**: a prompt written for redmoon may call a tool denomine-mcp lacks.
2. **Listing does not prove assignability**: Redmine decides assignability from role and setting data that the memberships response does not include.

### Mitigations

- The description names the conditions under which a listed principal can be assigned, so a model can explain a rejected assignment from Redmine's validation error.

## References

- [ADR-005](./adr-005-tool-surface.md) — the tool surface this ADR refines.
- [Redmine REST API: Memberships](https://www.redmine.org/projects/redmine/wiki/Rest_Memberships) — the endpoint the tool wraps.
- [redmine/redmine `lib/redmine/preparation.rb`](https://github.com/redmine/redmine/blob/master/lib/redmine/preparation.rb) — the `view_members` permission.
- [redmine/redmine `app/controllers/users_controller.rb`](https://github.com/redmine/redmine/blob/master/app/controllers/users_controller.rb) and [`groups_controller.rb`](https://github.com/redmine/redmine/blob/master/app/controllers/groups_controller.rb) — `require_admin` on every action but `show`, which rules out `index`.
- [redmine/redmine `app/models/project.rb`](https://github.com/redmine/redmine/blob/master/app/models/project.rb) — `assignable_users`, which allows only `User` and, with the setting, `Group`.
