///|
/// The Redmine operations behind `redmine_enumerations`.
pub(open) trait EnumerationPort {
  async fn list_time_entry_activities(Self) -> Array[@redmine.Enumeration] raise @redmine.RedmineError
  async fn list_issue_priorities(Self) -> Array[@redmine.Enumeration] raise @redmine.RedmineError
  async fn list_document_categories(Self) -> Array[@redmine.Enumeration] raise @redmine.RedmineError
}

///|
pub impl EnumerationPort for @redmine.Redmine with fn list_time_entry_activities(
  self,
) {
  self.list_time_entry_activities()
}

///|
pub impl EnumerationPort for @redmine.Redmine with fn list_issue_priorities(
  self,
) {
  self.list_issue_priorities()
}

///|
pub impl EnumerationPort for @redmine.Redmine with fn list_document_categories(
  self,
) {
  self.list_document_categories()
}
