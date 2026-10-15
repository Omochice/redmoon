///|
/// The Redmine operations behind `redmine_versions`.
pub(open) trait VersionPort {
  async fn list_versions(Self, project : @redmine.ProjectRef) -> Array[
    @redmine.Version,
  ] raise @redmine.RedmineError
  async fn show_version(Self, id : Int32) -> @redmine.Version raise @redmine.RedmineError
  async fn create_version(
    Self,
    project : @redmine.ProjectRef,
    attributes : @redmine.VersionCreate,
  ) -> @redmine.Version raise @redmine.RedmineError
  async fn update_version(Self, id : Int32, attributes : @redmine.VersionUpdate) -> Unit raise @redmine.RedmineError
  async fn delete_version(Self, id : Int32) -> Unit raise @redmine.RedmineError
}

///|
pub impl VersionPort for @redmine.Redmine with fn list_versions(self, project) {
  self.list_versions(project)
}

///|
pub impl VersionPort for @redmine.Redmine with fn show_version(self, id) {
  self.show_version(id)
}

///|
pub impl VersionPort for @redmine.Redmine with fn create_version(
  self,
  project,
  attributes,
) {
  self.create_version(project, attributes)
}

///|
pub impl VersionPort for @redmine.Redmine with fn update_version(
  self,
  id,
  attributes,
) {
  self.update_version(id, attributes)
}

///|
pub impl VersionPort for @redmine.Redmine with fn delete_version(self, id) {
  self.delete_version(id)
}
