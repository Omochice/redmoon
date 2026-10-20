///|
/// The Redmine operations behind `redmine_enumerations`.
pub(open) trait EnumerationPort {
  async fn list_time_entry_activities(Self) -> Array[@enumerations.Enumeration] raise @redmine.RedmineError
  async fn list_issue_priorities(Self) -> Array[@enumerations.Enumeration] raise @redmine.RedmineError
  async fn list_document_categories(Self) -> Array[@enumerations.Enumeration] raise @redmine.RedmineError
  async fn list_issue_queries(Self) -> Array[@queries.Query] raise @redmine.RedmineError
}

///|
pub impl EnumerationPort for @redmine.Redmine with fn list_time_entry_activities(
  self,
) {
  self |> @enumerations.time_entry_activities()
}

///|
pub impl EnumerationPort for @redmine.Redmine with fn list_issue_priorities(
  self,
) {
  self |> @enumerations.issue_priorities()
}

///|
pub impl EnumerationPort for @redmine.Redmine with fn list_document_categories(
  self,
) {
  self |> @enumerations.document_categories()
}

///|
pub impl EnumerationPort for @redmine.Redmine with fn list_issue_queries(self) {
  self |> @queries.list()
}
