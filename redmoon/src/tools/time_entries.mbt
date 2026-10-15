///|
priv enum TimeEntryAction {
  ListEntries(@redmine.TimeEntryListQuery)
  ShowEntry(Int32)
  CreateEntry(@redmine.TimeEntryCreate)
  UpdateEntry(Int32, @redmine.TimeEntryUpdate)
  DeleteEntry(Int32)
}

///|
let time_entry_id : @schema.Field[Int32] = @schema.required("id", record_id())

///|
let time_entry_list_input : @schema.Schema[TimeEntryAction] = {
  let project_id = @schema.optional("project_id", record_id())
  let user_id = @schema.optional("user_id", record_id())
  let spent_on = @schema.optional("spent_on", @schema.iso_date())
  let from = @schema.optional("from", @schema.iso_date())
  let to = @schema.optional("to", @schema.iso_date())
  @schema.record(
    [
      project_id.as_member(),
      user_id.as_member(),
      spent_on.as_member(),
      from.as_member(),
      to.as_member(),
    ],
    v => {
      ListEntries({
        project_id: v.get(project_id),
        user_id: v.get(user_id),
        spent_on: v.get(spent_on),
        from: v.get(from),
        to: v.get(to),
      })
    },
  )
}

///|
let time_entry_show_input : @schema.Schema[TimeEntryAction] = @schema.record(
  [time_entry_id.as_member()],
  v => ShowEntry(v.get(time_entry_id)),
)

///|
let time_entry_issue_id : @schema.Field[Int32?] = @schema.optional(
  "issue_id",
  record_id(),
)

///|
let time_entry_project_id : @schema.Field[Int32?] = @schema.optional(
  "project_id",
  record_id(),
)

///|
let time_entry_spent_on : @schema.Field[String?] = @schema.optional(
  "spent_on",
  @schema.iso_date(),
)

///|
let time_entry_activity_id : @schema.Field[Int32?] = @schema.optional(
  "activity_id",
  record_id(),
)

///|
let time_entry_comments : @schema.Field[String?] = @schema.optional(
  "comments",
  @schema.string(),
)

///|
let time_entry_create_input : @schema.Schema[TimeEntryAction] = {
  let hours = @schema.required("hours", @schema.number())
  @schema.record(
    [
      hours.as_member(),
      time_entry_issue_id.as_member(),
      time_entry_project_id.as_member(),
      time_entry_spent_on.as_member(),
      time_entry_activity_id.as_member(),
      time_entry_comments.as_member(),
    ],
    v => {
      CreateEntry({
        hours: v.get(hours),
        issue_id: v.get(time_entry_issue_id),
        project_id: v.get(time_entry_project_id),
        spent_on: v.get(time_entry_spent_on),
        activity_id: v.get(time_entry_activity_id),
        comments: v.get(time_entry_comments),
      })
    },
  )
}

///|
let time_entry_update_input : @schema.Schema[TimeEntryAction] = {
  let hours = @schema.optional("hours", @schema.number())
  @schema.record(
    [
      time_entry_id.as_member(),
      hours.as_member(),
      time_entry_issue_id.as_member(),
      time_entry_project_id.as_member(),
      time_entry_spent_on.as_member(),
      time_entry_activity_id.as_member(),
      time_entry_comments.as_member(),
    ],
    v => {
      UpdateEntry(v.get(time_entry_id), {
        hours: v.get(hours),
        issue_id: v.get(time_entry_issue_id),
        project_id: v.get(time_entry_project_id),
        spent_on: v.get(time_entry_spent_on),
        activity_id: v.get(time_entry_activity_id),
        comments: v.get(time_entry_comments),
      })
    },
  )
}

///|
let time_entry_delete_input : @schema.Schema[TimeEntryAction] = @schema.record(
  [time_entry_id.as_member()],
  v => DeleteEntry(v.get(time_entry_id)),
)

///|
/// Readonly drops the write actions so a write is inexpressible in the schema
/// rather than rejected after parsing.
fn time_entry_input(mode : Mode) -> @schema.Schema[TimeEntryAction] {
  let read = [("list", time_entry_list_input), ("show", time_entry_show_input)]
  let write = [
    ("create", time_entry_create_input),
    ("update", time_entry_update_input),
    ("delete", time_entry_delete_input),
  ]
  @schema.keyed(
    match mode {
      Full => [..read, ..write]
      Readonly => read
    },
  )
}

///|
/// `redmine_time_entries`: the time logged against issues and projects.
pub fn time_entries_tool(port : &TimeEntryPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_time_entries",
    description=describe_crud_tool("time entries", mode),
    input=time_entry_input(mode),
    handler=async fn(action) {
      match action {
        ListEntries(query) => respond(() => port.list_time_entries(query))
        ShowEntry(id) => respond(() => port.show_time_entry(id))
        CreateEntry(time_entry) =>
          respond(() => port.create_time_entry(time_entry))
        UpdateEntry(id, time_entry) =>
          respond_ok(() => port.update_time_entry(id, time_entry))
        DeleteEntry(id) => respond_ok(() => port.delete_time_entry(id))
      }
    },
  )
}
