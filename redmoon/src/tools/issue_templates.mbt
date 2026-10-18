///|
priv enum IssueTemplateAction {
  List(@redmine.ProjectRef, Int32)
}

///|
fn issue_templates_input() -> @schema.Schema[IssueTemplateAction] {
  let project_id = @schema.required("project_id", project_ref())
  let tracker_id = @schema.required("tracker_id", record_id())
  @schema.keyed([
    (
      "list",
      @schema.record([project_id.as_member(), tracker_id.as_member()], v => {
        IssueTemplateAction::List(v.get(project_id), v.get(tracker_id))
      }),
    ),
  ])
}

///|
/// `redmine_issue_templates`: the templates of the redmine_issue_templates plugin.
/// The plugin offers no API to change templates, so the tool is the same in both modes.
pub fn issue_templates_tool(port : &IssueTemplatePort) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_issue_templates",
    description="Lists the issue templates a Redmine project offers for new issues of one tracker: the global templates enabled for it, those inherited from its parent projects, and its own.\n`tracker_id` is the tracker's id, as an issue from `redmine_issues` carries it under `tracker`.\nNeeds the redmine_issue_templates plugin; an instance without it answers 404.\nPass the arguments under the single key `list`: `{\"list\": {\"project_id\": \"demo\", \"tracker_id\": 1}}`.",
    input=issue_templates_input(),
    handler=async fn(action) {
      match action {
        List(project, tracker_id) =>
          respond(() => port.list_issue_templates(project, tracker_id))
      }
    },
  )
}
