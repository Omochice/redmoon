///|
/// The Redmine operations behind `redmine_issues`.
pub(open) trait IssuePort {
  async fn list_issues(Self, query : @issues.ListQuery, limit : Int32?) -> Array[
    @issues.Issue,
  ] raise @redmine.RedmineError
  async fn list_saved_issues(Self, query : @issues.SavedQuery, limit : Int32?) -> Array[
    @issues.Issue,
  ] raise @redmine.RedmineError
  async fn list_queries(Self) -> Array[@queries.Query] raise @redmine.RedmineError
  async fn show_issue(Self, id : Int32, includes : Array[@issues.Include]) -> @issues.Issue raise @redmine.RedmineError
  async fn create_issue(Self, issue : @issues.Create) -> @issues.Issue raise @redmine.RedmineError
  async fn update_issue(Self, id : Int32, update : @issues.Update) -> Unit raise @redmine.RedmineError
  async fn delete_issue(Self, id : Int32) -> Unit raise @redmine.RedmineError
  async fn update_journal(
    Self,
    id : Int32,
    notes : String?,
    private_notes : Bool?,
  ) -> Unit raise @redmine.RedmineError
}

///|
pub impl IssuePort for @redmine.Redmine with fn list_issues(self, query, limit) {
  self |> @issues.list(query, limit?)
}

///|
pub impl IssuePort for @redmine.Redmine with fn list_saved_issues(
  self,
  query,
  limit,
) {
  self |> @issues.list(query, limit?)
}

///|
pub impl IssuePort for @redmine.Redmine with fn list_queries(self) {
  self |> @queries.list()
}

///|
pub impl IssuePort for @redmine.Redmine with fn show_issue(self, id, includes) {
  self |> @issues.show(id, includes~)
}

///|
pub impl IssuePort for @redmine.Redmine with fn create_issue(self, issue) {
  self |> @issues.create(issue)
}

///|
pub impl IssuePort for @redmine.Redmine with fn update_issue(self, id, update) {
  self |> @issues.update(id, update)
}

///|
pub impl IssuePort for @redmine.Redmine with fn delete_issue(self, id) {
  self |> @issues.delete(id)
}

///|
pub impl IssuePort for @redmine.Redmine with fn update_journal(
  self,
  id,
  notes,
  private_notes,
) {
  self |> @issues.update_journal(id, notes?, private_notes?)
}
