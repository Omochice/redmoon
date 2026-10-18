///|
/// The Redmine operations behind `redmine_issue_templates`.
pub(open) trait IssueTemplatePort {
  async fn list_issue_templates(
    Self,
    project : @redmine.ProjectRef,
    tracker_id : Int32,
  ) -> @issue_templates.Templates raise @redmine.RedmineError
}

///|
pub impl IssueTemplatePort for @redmine.Redmine with fn list_issue_templates(
  self,
  project,
  tracker_id,
) {
  self |> @issue_templates.list(project, tracker_id~)
}
