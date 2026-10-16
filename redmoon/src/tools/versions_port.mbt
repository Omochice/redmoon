///|
/// The Redmine operations behind `redmine_versions`.
pub(open) trait VersionPort {
  async fn list_versions(Self, project : @redmine.ProjectRef) -> Array[
    @versions.Version,
  ] raise @redmine.RedmineError
  async fn show_version(Self, id : Int32) -> @versions.Version raise @redmine.RedmineError
  async fn create_version(
    Self,
    project : @redmine.ProjectRef,
    attributes : @versions.Create,
  ) -> @versions.Version raise @redmine.RedmineError
  async fn update_version(Self, id : Int32, attributes : @versions.Update) -> Unit raise @redmine.RedmineError
  async fn delete_version(Self, id : Int32) -> Unit raise @redmine.RedmineError
}

///|
pub impl VersionPort for @redmine.Redmine with fn list_versions(self, project) {
  self |> @versions.list(project)
}

///|
pub impl VersionPort for @redmine.Redmine with fn show_version(self, id) {
  self |> @versions.show(id)
}

///|
pub impl VersionPort for @redmine.Redmine with fn create_version(
  self,
  project,
  attributes,
) {
  self |> @versions.create(project, attributes)
}

///|
pub impl VersionPort for @redmine.Redmine with fn update_version(
  self,
  id,
  attributes,
) {
  self |> @versions.update(id, attributes)
}

///|
pub impl VersionPort for @redmine.Redmine with fn delete_version(self, id) {
  self |> @versions.delete(id)
}
