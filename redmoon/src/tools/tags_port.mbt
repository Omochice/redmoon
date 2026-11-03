///|
/// The Redmine operations behind `redmine_tags`.
pub(open) trait TagPort {
  async fn show_issue_tags(Self, issue_id : Int32) -> Array[String] raise @redmine.RedmineError
  async fn add_issue_tags(Self, issue_id : Int32, names : Array[String]) -> Array[
    String,
  ] raise @redmine.RedmineError
  async fn remove_issue_tags(Self, issue_id : Int32, names : Array[String]) -> Array[
    String,
  ] raise @redmine.RedmineError
  async fn list_issue_tags(Self) -> Array[@additional_tags.Tag] raise @redmine.RedmineError
  async fn list_tagged_issues(
    Self,
    names : Array[String],
    project_id : Int32?,
    status_id : @issues.StatusFilter?,
    limit : Int32?,
  ) -> Array[@issues.Issue] raise @redmine.RedmineError
  async fn list_tagged_wiki_pages(
    Self,
    project : @redmine.ProjectRef,
    name : String,
  ) -> Array[@wiki.PageSummary] raise @redmine.RedmineError
}

///|
pub impl TagPort for @redmine.Redmine with fn show_issue_tags(self, issue_id) {
  self |> @additional_tags.tags(issue_id)
}

///|
pub impl TagPort for @redmine.Redmine with fn add_issue_tags(
  self,
  issue_id,
  names,
) {
  self |> @additional_tags.add(issue_id, names)
}

///|
pub impl TagPort for @redmine.Redmine with fn remove_issue_tags(
  self,
  issue_id,
  names,
) {
  self |> @additional_tags.remove(issue_id, names)
}

///|
pub impl TagPort for @redmine.Redmine with fn list_issue_tags(self) {
  self |> @additional_tags.list()
}

///|
pub impl TagPort for @redmine.Redmine with fn list_tagged_issues(
  self,
  names,
  project_id,
  status_id,
  limit,
) {
  self |> @additional_tags.list_issues(names, project_id?, status_id?, limit?)
}

///|
pub impl TagPort for @redmine.Redmine with fn list_tagged_wiki_pages(
  self,
  project,
  name,
) {
  self |> @additional_tags.list_wiki_pages(project, name)
}
