///|
/// The Redmine operation behind `redmine_search`.
pub(open) trait SearchPort {
  async fn search(Self, query : @redmine.SearchQuery) -> Array[
    @redmine.SearchResult,
  ] raise @redmine.RedmineError
}

///|
pub impl SearchPort for @redmine.Redmine with fn search(self, query) {
  self.search(query)
}
