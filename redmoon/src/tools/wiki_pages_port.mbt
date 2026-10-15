///|
/// The Redmine operations behind `redmine_wiki_pages`.
pub(open) trait WikiPagePort {
  async fn list_wiki_pages(Self, project : @redmine.ProjectRef) -> Array[
    @redmine.WikiPageSummary,
  ] raise @redmine.RedmineError
  async fn show_wiki_page(
    Self,
    project : @redmine.ProjectRef,
    title : String,
    version? : Int32,
  ) -> @redmine.WikiPage raise @redmine.RedmineError
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
  self.list_wiki_pages(project)
}

///|
pub impl WikiPagePort for @redmine.Redmine with fn show_wiki_page(
  self,
  project,
  title,
  version?,
) {
  self.show_wiki_page(project, title, version?)
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
  self.create_wiki_page(project, title, text, comments?, parent_title?)
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
  self.update_wiki_page(
    project,
    title,
    text,
    comments?,
    version?,
    parent_title?,
  )
}

///|
pub impl WikiPagePort for @redmine.Redmine with fn delete_wiki_page(
  self,
  project,
  title,
) {
  self.delete_wiki_page(project, title)
}
