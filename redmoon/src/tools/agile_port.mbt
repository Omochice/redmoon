///|
/// The Redmine operations behind `redmine_agile`.
pub(open) trait AgilePort {
  async fn get_agile_data(Self, issue_id : Int32) -> @agile.AgileData raise @redmine.RedmineError
  async fn update_agile_data(Self, issue_id : Int32, attributes : @agile.Update) -> Unit raise @redmine.RedmineError
}

///|
pub impl AgilePort for @redmine.Redmine with fn get_agile_data(self, issue_id) {
  self |> @agile.get(issue_id)
}

///|
pub impl AgilePort for @redmine.Redmine with fn update_agile_data(
  self,
  issue_id,
  attributes,
) {
  self |> @agile.update(issue_id, attributes)
}
