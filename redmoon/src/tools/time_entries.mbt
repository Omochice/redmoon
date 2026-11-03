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
    let project_id = @schema.optional(
      "project_id",
      record_id().describe("Project whose entries to list."),
    )
    let user_id = @schema.optional(
      "user_id",
      record_id().describe("User who logged the entries."),
    )
    let spent_on = @schema.optional(
      "spent_on",
      @schema.iso_date().describe(
        "Single day the time was spent on, as an ISO date (`YYYY-MM-DD`).",
      ),
    )
    let from = @schema.optional(
      "from",
      @schema.iso_date().describe(
        "First day of the period, as an ISO date (`YYYY-MM-DD`).",
      ),
    )
    let to = @schema.optional(
      "to",
      @schema.iso_date().describe(
        "Last day of the period, as an ISO date (`YYYY-MM-DD`).",
      ),
    )
    @schema.record(
      [
        project_id.as_member(),
        user_id.as_member(),
        spent_on.as_member(),
        from.as_member(),
        to.as_member(),
      ],
      v => {
        TimeEntryAction::List(
          @time_entries.ListQuery::new(
            project_id?=v.get(project_id),
            user_id?=v.get(user_id),
            spent_on?=v.get(spent_on),
            from?=v.get(from),
            to?=v.get(to),
          ),
        )
      },
    )
  }
  let show_input = @schema.record([id.as_member()], v => {
    TimeEntryAction::Show(v.get(id))
  })
  let hours_schema = @schema.number(min=0.0).describe(
    "Hours spent, as a decimal number such as `1.5`.",
  )
  let issue_id = @schema.optional(
    "issue_id",
    record_id().describe(
      "Issue the time was spent on; Redmine takes the project from it.",
    ),
  )
  let project_id = @schema.optional(
    "project_id",
    record_id().describe(
      "Project the time was spent on, for time not tied to an issue.",
    ),
  )
  let spent_on = @schema.optional(
    "spent_on",
    @schema.iso_date().describe(
      "Day the time was spent, as an ISO date (`YYYY-MM-DD`); today by default.",
    ),
  )
  let activity_id = @schema.optional(
    "activity_id",
    record_id().describe(
      "Activity to log the time under, by the id `redmine_enumerations` lists with `list_time_entry_activities`.",
    ),
  )
  let comments = @schema.optional(
    "comments",
    @schema.string(max_length=1024).describe(
      "Comment shown with the entry, at most 1024 characters.",
    ),
  )
  // Redmine derives the project from the issue, so a new entry is accepted with
  // either one or both but rejected with neither.
  let create_input = {
    let hours = @schema.required("hours", hours_schema)
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
        TimeEntryAction::Create(
          @time_entries.Create::new(
            hours=v.get(hours),
            issue_id?=v.get(issue_id),
            project_id?=v.get(project_id),
            spent_on?=v.get(spent_on),
            activity_id?=v.get(activity_id),
            comments?=v.get(comments),
          ),
        )
      },
    ).require_any([issue_id.as_member(), project_id.as_member()])
  }
  let update_input = {
    let hours = @schema.optional("hours", hours_schema)
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
        TimeEntryAction::Update(
          v.get(id),
          @time_entries.Update::new(
            hours?=v.get(hours),
            issue_id?=v
              .get(issue_id)
              .map(value => @redmine.Clearable::Set(value)),
            project_id?=v.get(project_id),
            spent_on?=v.get(spent_on),
            activity_id?=v.get(activity_id),
            comments?=v
              .get(comments)
              .map(value => @redmine.Clearable::Set(value)),
          ),
        )
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
