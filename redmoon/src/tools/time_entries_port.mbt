///|
/// The Redmine operations behind `redmine_time_entries`.
pub(open) trait TimeEntryPort {
  async fn list_time_entries(Self, query : @redmine.TimeEntryListQuery) -> Array[
    @redmine.TimeEntry,
  ] raise @redmine.RedmineError
  async fn show_time_entry(Self, id : Int32) -> @redmine.TimeEntry raise @redmine.RedmineError
  async fn create_time_entry(Self, time_entry : @redmine.TimeEntryCreate) -> @redmine.TimeEntry raise @redmine.RedmineError
  async fn update_time_entry(
    Self,
    id : Int32,
    time_entry : @redmine.TimeEntryUpdate,
  ) -> Unit raise @redmine.RedmineError
  async fn delete_time_entry(Self, id : Int32) -> Unit raise @redmine.RedmineError
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn list_time_entries(
  self,
  query,
) {
  self.list_time_entries(query)
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn show_time_entry(self, id) {
  self.show_time_entry(id)
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn create_time_entry(
  self,
  time_entry,
) {
  self.create_time_entry(time_entry)
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn update_time_entry(
  self,
  id,
  time_entry,
) {
  self.update_time_entry(id, time_entry)
}

///|
pub impl TimeEntryPort for @redmine.Redmine with fn delete_time_entry(self, id) {
  self.delete_time_entry(id)
}
