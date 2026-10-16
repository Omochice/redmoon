///|
/// The Redmine operations behind `redmine_wiki_pages`.
pub(open) trait WikiPagePort {
  async fn list_wiki_pages(Self, project : @redmine.ProjectRef) -> Array[
    @wiki.PageSummary,
  ] raise @redmine.RedmineError
  async fn show_wiki_page(
    Self,
    project : @redmine.ProjectRef,
    title : String,
    version? : Int32,
  ) -> @wiki.Page raise @redmine.RedmineError
  async fn create_wiki_page(
    Self,
    project : @redmine.ProjectRef,
    title : String,
    text : String,
    comments? : String,
    parent_title? : String,
  ) -> Unit raise @redmine.RedmineError
  async fn update_wiki_page(
    Self,
    project : @redmine.ProjectRef,
    title : String,
    text : String,
    comments? : String,
    version? : Int32,
    parent_title? : String,
  ) -> Unit raise @redmine.RedmineError
  async fn delete_wiki_page(Self, project : @redmine.ProjectRef, title : String) -> Unit raise @redmine.RedmineError
}

///|
pub impl WikiPagePort for @redmine.Redmine with fn list_wiki_pages(
  self,
  project,
) {
  self |> @wiki.list(project)
}

///|
pub impl WikiPagePort for @redmine.Redmine with fn show_wiki_page(
  self,
  project,
  title,
  version?,
) {
  self |> @wiki.show(project, title, version?)
}

///|
pub impl WikiPagePort for @redmine.Redmine with fn create_wiki_page(
  self,
  project,
  title,
  text,
  comments?,
  parent_title?,
) {
  self |> @wiki.create(project, title, text, comments?, parent_title?)
}

///|
pub impl WikiPagePort for @redmine.Redmine with fn update_wiki_page(
  self,
  project,
  title,
  text,
  comments?,
  version?,
  parent_title?,
) {
  self |> @wiki.update(project, title, text, comments?, version?, parent_title?)
}

///|
pub impl WikiPagePort for @redmine.Redmine with fn delete_wiki_page(
  self,
  project,
  title,
) {
  self |> @wiki.delete(project, title)
}
