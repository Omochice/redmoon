///|
priv enum EnumerationAction {
  TimeEntryActivities
  IssuePriorities
  DocumentCategories
}

///|
let enumeration_input : @schema.Schema[EnumerationAction] = @schema.keyed([
  (
    "list_time_entry_activities",
    @schema.object(TimeEntryActivities) |> @schema.Obj::done,
  ),
  (
    "list_issue_priorities",
    @schema.object(IssuePriorities) |> @schema.Obj::done,
  ),
  (
    "list_document_categories",
    @schema.object(DocumentCategories) |> @schema.Obj::done,
  ),
])

///|
/// `redmine_enumerations`: the listings that supply ids other tools require.
/// Every action only reads, so the tool is the same in both modes.
pub fn enumerations_tool(port : &EnumerationPort) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_enumerations",
    description="Lists the Redmine enumerations that supply ids other tools require: time entry activities for `activity_id`, issue priorities for `priority_id`, and document categories.\nName the listing as the only key, with an empty object as its value: `{\"list_issue_priorities\": {}}`.",
    input=enumeration_input,
    handler=async fn(action) {
      match action {
        TimeEntryActivities => respond(() => port.list_time_entry_activities())
        IssuePriorities => respond(() => port.list_issue_priorities())
        DocumentCategories => respond(() => port.list_document_categories())
      }
    },
  )
}
