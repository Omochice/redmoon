///|
/// The Redmine operations behind `redmine_time_entries`.
pub(open) trait TimeEntryPort {
  async fn list_time_entries(Self, query : @time_entries.ListQuery) -> Array[
    @time_entries.Entry,
  ] raise @redmine.RedmineError
  async fn show_time_entry(Self, id : Int32) -> @time_entries.Entry raise @redmine.RedmineError
  async fn create_time_entry(Self, time_entry : @time_entries.Create) -> @time_entries.Entry raise @redmine.RedmineError
  async fn update_time_entry(
    Self,
    id : Int32,
    time_entry : @time_entries.Update,
  ) -> Unit raise @redmine.RedmineError
  async fn delete_time_entry(Self, id : Int32) -> Unit raise @redmine.RedmineError
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn list_time_entries(
  self,
  query,
) {
  self |> @time_entries.list(query)
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn show_time_entry(self, id) {
  self |> @time_entries.show(id)
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn create_time_entry(
  self,
  time_entry,
) {
  self |> @time_entries.create(time_entry)
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn update_time_entry(
  self,
  id,
  time_entry,
) {
  self |> @time_entries.update(id, time_entry)
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn delete_time_entry(self, id) {
  self |> @time_entries.delete(id)
}
