///|
priv enum TimeEntryAction {
  List(@time_entries.ListQuery)
  Show(Int32)
  Create(@time_entries.Create)
  Update(Int32, @time_entries.Update)
  Delete(Int32)
}

///|
/// Readonly drops the write actions so a write is inexpressible in the schema
/// rather than rejected after parsing.
fn time_entries_input(mode : Mode) -> @schema.Schema[TimeEntryAction] {
  let id = @schema.required("id", record_id())
  let list_input = {
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
        TimeEntryAction::List({
          project_id: v.get(project_id),
          user_id: v.get(user_id),
          spent_on: v.get(spent_on),
          from: v.get(from),
          to: v.get(to),
        })
      },
    )
  }
  let show_input = @schema.record([id.as_member()], v => {
    TimeEntryAction::Show(v.get(id))
  })
  let issue_id = @schema.optional("issue_id", record_id())
  let project_id = @schema.optional("project_id", record_id())
  let spent_on = @schema.optional("spent_on", @schema.iso_date())
  let activity_id = @schema.optional("activity_id", record_id())
  let comments = @schema.optional("comments", @schema.string(max_length=1024))
  // Redmine derives the project from the issue, so a new entry is accepted with
  // either one or both but rejected with neither.
  let create_input = {
    let hours = @schema.required("hours", @schema.number(min=0.0))
    @schema.record(
      [
        hours.as_member(),
        issue_id.as_member(),
        project_id.as_member(),
        spent_on.as_member(),
        activity_id.as_member(),
        comments.as_member(),
      ],
      v => {
        TimeEntryAction::Create({
          hours: v.get(hours),
          issue_id: v.get(issue_id),
          project_id: v.get(project_id),
          spent_on: v.get(spent_on),
          activity_id: v.get(activity_id),
          comments: v.get(comments),
        })
      },
    ).require_any([issue_id.as_member(), project_id.as_member()])
  }
  let update_input = {
    let hours = @schema.optional("hours", @schema.number(min=0.0))
    @schema.record(
      [
        id.as_member(),
        hours.as_member(),
        issue_id.as_member(),
        project_id.as_member(),
        spent_on.as_member(),
        activity_id.as_member(),
        comments.as_member(),
      ],
      v => {
        TimeEntryAction::Update(v.get(id), {
          hours: v.get(hours),
          issue_id: v.get(issue_id),
          project_id: v.get(project_id),
          spent_on: v.get(spent_on),
          activity_id: v.get(activity_id),
          comments: v.get(comments),
        })
      },
    )
  }
  let delete_input = @schema.record([id.as_member()], v => {
    TimeEntryAction::Delete(v.get(id))
  })
  let read = [("list", list_input), ("show", show_input)]
  let write = [
    ("create", create_input),
    ("update", update_input),
    ("delete", delete_input),
  ]
  actions(mode, read~, write~)
}

///|
/// `redmine_time_entries`: the time logged against issues and projects.
pub fn time_entries_tool(port : &TimeEntryPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_time_entries",
    description=describe_crud_tool("time entries", mode),
    input=time_entries_input(mode),
    handler=async fn(action) {
      match action {
        List(query) => respond(() => port.list_time_entries(query))
        Show(id) => respond(() => port.show_time_entry(id))
        Create(time_entry) => respond(() => port.create_time_entry(time_entry))
        Update(id, time_entry) =>
          respond_ok(() => port.update_time_entry(id, time_entry))
        Delete(id) => respond_ok(() => port.delete_time_entry(id))
      }
    },
  )
}
