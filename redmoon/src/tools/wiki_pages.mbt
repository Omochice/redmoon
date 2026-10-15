///|
priv enum WikiPageAction {
  List(@redmine.ProjectRef)
  Show(@redmine.ProjectRef, String, Int32?)
  Create(@redmine.ProjectRef, String, String, String?, String?)
  Update(@redmine.ProjectRef, String, String, String?, Int32?, String?)
  Delete(@redmine.ProjectRef, String)
}

///|
fn wiki_title() -> @schema.Schema[String] {
  @schema.not_blank().describe(
    "Wiki page title. When taken from a URL, percent-decode it first; Redmine stores spaces as underscores, so either form of a multi-word title works.",
  )
}

///|
fn wiki_pages_input(mode : Mode) -> @schema.Schema[WikiPageAction] {
  let read = [
    (
      "list",
      @schema.object(p => WikiPageAction::List(p))
      |> @schema.field("project_id", project_ref())
      |> @schema.Obj::done,
    ),
    (
      "show",
      @schema.object(p => t => v => WikiPageAction::Show(p, t, v))
      |> @schema.field("project_id", project_ref())
      |> @schema.field("title", wiki_title())
      |> @schema.optional("version", record_id())
      |> @schema.Obj::done,
    ),
  ]
  let write = [
    (
      "create",
      @schema.object(p => {
        t => x => c => pt => WikiPageAction::Create(p, t, x, c, pt)
      })
      |> @schema.field("project_id", project_ref())
      |> @schema.field("title", wiki_title())
      |> @schema.field("text", @schema.string())
      |> @schema.optional("comments", @schema.string())
      |> @schema.optional("parent_title", @schema.string())
      |> @schema.Obj::done,
    ),
    (
      "update",
      @schema.object(p => {
        t => x => c => v => pt => WikiPageAction::Update(p, t, x, c, v, pt)
      })
      |> @schema.field("project_id", project_ref())
      |> @schema.field("title", wiki_title())
      |> @schema.field("text", @schema.string())
      |> @schema.optional("comments", @schema.string())
      |> @schema.optional("version", record_id())
      |> @schema.optional("parent_title", @schema.string())
      |> @schema.Obj::done,
    ),
    (
      "delete",
      @schema.object(p => t => WikiPageAction::Delete(p, t))
      |> @schema.field("project_id", project_ref())
      |> @schema.field("title", wiki_title())
      |> @schema.Obj::done,
    ),
  ]
  match mode {
    Full => @schema.keyed([..read, ..write])
    Readonly => @schema.keyed(read)
  }
}

///|
/// `redmine_wiki_pages`: the wiki pages of a project. `Readonly` mode leaves
/// out create, update, and delete.
pub fn wiki_pages_tool(port : &WikiPagePort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_wiki_pages",
    description=describe_crud_tool("wiki pages", mode),
    input=wiki_pages_input(mode),
    handler=async fn(action) {
      match action {
        List(project) => respond(() => port.list_wiki_pages(project))
        Show(project, title, version) =>
          respond(() => port.show_wiki_page(project, title, version?))
        Create(project, title, text, comments, parent_title) =>
          respond_ok(() => {
            port.create_wiki_page(
              project,
              title,
              text,
              comments?,
              parent_title?,
            )
          })
        Update(project, title, text, comments, version, parent_title) =>
          respond_ok(() => {
            port.update_wiki_page(
              project,
              title,
              text,
              comments?,
              version?,
              parent_title?,
            )
          })
        Delete(project, title) =>
          respond_ok(() => port.delete_wiki_page(project, title))
      }
    },
  )
}
