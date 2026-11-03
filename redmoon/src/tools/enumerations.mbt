///|
priv enum EnumerationAction {
  TimeEntryActivities
  IssuePriorities
  DocumentCategories
}

///|
fn enumerations_input() -> @schema.Schema[EnumerationAction] {
  @schema.keyed([
    ("list_time_entry_activities", @schema.record([], _ => TimeEntryActivities)),
    ("list_issue_priorities", @schema.record([], _ => IssuePriorities)),
    ("list_document_categories", @schema.record([], _ => DocumentCategories)),
  ])
}

///|
/// `redmine_enumerations`: the listings that supply ids other tools require.
/// Every action only reads, so the tool is the same in both modes.
pub fn enumerations_tool(port : &EnumerationPort) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_enumerations",
    description=describe_tool([
      "Lists the Redmine enumerations that supply ids other tools require: time entry activities for `activity_id`, issue priorities for `priority_id`, and document categories.",
    ]),
    input=enumerations_input(),
    handler=async fn(action) {
      match action {
        TimeEntryActivities => respond(() => port.list_time_entry_activities())
        IssuePriorities => respond(() => port.list_issue_priorities())
        DocumentCategories => respond(() => port.list_document_categories())
      }
    },
  )
}
