# ADR-034: Design Evolution from ADR-028

## Status

Accepted

## Context

[ADR-028](./adr-028-tool-surface.md) decided that every argument and response key of the tools is in snake_case, so that the names a model reads in a response are the names it sends back, and no layer between the Redmine wire and the model renames anything.

The decision speaks of keys.
Some arguments also accept a value from a closed set of names, such as the associations `include` can ask for and the named periods a date filter can take, and those names were still the camelCase ones denomine-mcp used.
Using the tools showed that the rationale of ADR-028 reaches these values as well: the SDK sends `allowed_statuses` on the wire and Redmine answers with that key, so a model read `allowed_statuses` in a `show` response and then had to send `allowedStatuses` to ask for it.

This ADR records that the snake_case rule covers the values a tool accepts, so that ADR-028 is read together with what the code does; every other decision of ADR-028 still holds as written.

## Design Changes from ADR-028

### 1. The closed-set values a tool accepts are in snake_case

#### Original Design (ADR-028)

Every argument and response key is in snake_case.
The values of `include` and the named periods of the date filters kept the spelling of denomine-mcp.

#### Revised Design

A value that a tool accepts from a closed set of names is in snake_case, like the key it belongs to.
The table below lists the values this renames; the periods are those of the date filters of `list`, and the forward-looking two are accepted only by `start_date` and `due_date`.

| Argument       | Before            | After              |
| -------------- | ----------------- | ------------------ |
| `show.include` | `allowedStatuses` | `allowed_statuses` |
| date filters   | `thisWeek`        | `this_week`        |
| date filters   | `lastWeek`        | `last_week`        |
| date filters   | `lastTwoWeeks`    | `last_two_weeks`   |
| date filters   | `thisMonth`       | `this_month`       |
| date filters   | `lastMonth`       | `last_month`       |
| date filters   | `thisYear`        | `this_year`        |
| date filters   | `nextWeek`        | `next_week`        |
| date filters   | `nextMonth`       | `next_month`       |

`today`, `yesterday`, `tomorrow`, `any`, and `none` are single words and are unchanged.

#### Rationale

ADR-028 chose snake_case so that a model reads a name in a response and passes it back unchanged.
`allowedStatuses` broke that promise: the SDK already asked Redmine for `allowed_statuses` and the response carried `allowed_statuses`, so the tool was the one layer that renamed something, in the direction ADR-028 set out to avoid.
The period names never appear in a response, but they sit beside keys like `days_ago` and `days_from_now` in the same argument, and a model that has learned one spelling for the surface should not have to keep a second one for a handful of values.

## Consequences

### Positive

1. **One spelling end to end**: a value read from a response is the value to send, which was the point of ADR-028.
2. **The surface has one naming rule**, for keys and for the values a key accepts.

### Negative

1. **A prompt written against the old value names fails** until it is updated.

### Mitigations

- A camelCase value is rejected with `no alternative matched: must be one of ...`, which lists the accepted spellings, so a model learns the new name from the error just as it learns a key from `unknown field`.

## References

- [ADR-028](./adr-028-tool-surface.md) — the decision this ADR refines.
- [Redmine REST API: Issues](https://www.redmine.org/projects/redmine/wiki/Rest_Issues) — `allowed_statuses` as the include name on the wire.
