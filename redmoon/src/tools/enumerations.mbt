///|
priv enum EnumerationAction {
  TimeEntryActivities
  IssuePriorities
  DocumentCategories
  IssueQueries
}

///|
let enumeration_input : @schema.Schema[EnumerationAction] = @schema.keyed([
  ("list_time_entry_activities", @schema.record([], _ => TimeEntryActivities)),
  ("list_issue_priorities", @schema.record([], _ => IssuePriorities)),
  ("list_document_categories", @schema.record([], _ => DocumentCategories)),
  ("list_issue_queries", @schema.record([], _ => IssueQueries)),
])

///|
/// `redmine_enumerations`: the listings that supply ids other tools require.
/// Every action only reads, so the tool is the same in both modes.
pub fn enumerations_tool(port : &EnumerationPort) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_enumerations",
    description="Lists the Redmine enumerations that supply ids other tools require: time entry activities for `activity_id`, issue priorities for `priority_id`, document categories, and saved issue queries for `query_id` of `redmine_issues` `list`.\nA saved query listed with a `project_id` belongs to that project and must be used with exactly that `project_id`; without it, or with a subproject's id, Redmine answers 404.\nName the listing as the only key, with an empty object as its value: `{\"list_issue_priorities\": {}}`.",
    input=enumeration_input,
    handler=async fn(action) {
      match action {
        TimeEntryActivities => respond(() => port.list_time_entry_activities())
        IssuePriorities => respond(() => port.list_issue_priorities())
        DocumentCategories => respond(() => port.list_document_categories())
        IssueQueries => respond(() => port.list_issue_queries())
      }
    },
  )
}
