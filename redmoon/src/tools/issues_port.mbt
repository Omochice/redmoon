///|
/// The Redmine operations behind `redmine_issues`.
pub(open) trait IssuePort {
  async fn list_issues(Self, @redmine.IssueListQuery, Int32?) -> Array[
    @redmine.Issue,
  ] raise @redmine.RedmineError
  async fn show_issue(Self, Int32, Array[@redmine.IssueInclude]) -> @redmine.Issue raise @redmine.RedmineError
  async fn create_issue(Self, @redmine.IssueCreate) -> @redmine.Issue raise @redmine.RedmineError
  async fn update_issue(Self, Int32, @redmine.IssueUpdate) -> Unit raise @redmine.RedmineError
  async fn delete_issue(Self, Int32) -> Unit raise @redmine.RedmineError
  async fn update_journal(Self, Int32, String?, Bool?) -> Unit raise @redmine.RedmineError
}

///|
pub impl IssuePort for @redmine.Redmine with fn list_issues(self, query, limit) {
  self.list_issues(query, limit?)
}

///|
pub impl IssuePort for @redmine.Redmine with fn show_issue(self, id, includes) {
  self.show_issue(id, includes~)
}

///|
pub impl IssuePort for @redmine.Redmine with fn create_issue(self, issue) {
  self.create_issue(issue)
}

///|
pub impl IssuePort for @redmine.Redmine with fn update_issue(self, id, update) {
  self.update_issue(id, update)
}

///|
pub impl IssuePort for @redmine.Redmine with fn delete_issue(self, id) {
  self.delete_issue(id)
}

///|
pub impl IssuePort for @redmine.Redmine with fn update_journal(
  self,
  id,
  notes,
  private_notes,
) {
  self.update_journal(id, notes?, private_notes?)
}
