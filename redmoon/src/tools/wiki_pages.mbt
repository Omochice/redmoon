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
  let project_id = @schema.required("project_id", project_ref())
  let title = @schema.required("title", wiki_title())
  let text = @schema.optional(
    "text",
    @schema.string().describe(
      "Content of the page. Exactly one of `text` and `text_path` is required.",
    ),
  )
  let text_path = text_path("text")
  // `text` is absent only while the arguments are validated before the
  // `text_path` file is read, since `exclusive_text` requires one of the two.
  fn page_text(v : @schema.Values) -> String raise @schema.SchemaError {
    v.get(text).unwrap_or("")
  }
  let comments = @schema.optional("comments", @schema.string())
  let version = @schema.optional("version", record_id())
  let parent_title = @schema.optional("parent_title", @schema.string())
  let read = [
    (
      "list",
      @schema.record([project_id.as_member()], v => {
        WikiPageAction::List(v.get(project_id))
      }),
    ),
    (
      "show",
      @schema.record(
        [project_id.as_member(), title.as_member(), version.as_member()],
        v => {
          WikiPageAction::Show(v.get(project_id), v.get(title), v.get(version))
        },
      ),
    ),
  ]
  let write = [
    (
      "create",
      exclusive_text(
        field="text",
        required=true,
        @schema.record(
          [
            project_id.as_member(),
            title.as_member(),
            text.as_member(),
            text_path.as_member(),
            comments.as_member(),
            parent_title.as_member(),
          ],
          v => {
            WikiPageAction::Create(
              v.get(project_id),
              v.get(title),
              page_text(v),
              v.get(comments),
              v.get(parent_title),
            )
          },
        ),
      ),
    ),
    (
      "update",
      exclusive_text(
        field="text",
        required=true,
        @schema.record(
          [
            project_id.as_member(),
            title.as_member(),
            text.as_member(),
            text_path.as_member(),
            comments.as_member(),
            version.as_member(),
            parent_title.as_member(),
          ],
          v => {
            WikiPageAction::Update(
              v.get(project_id),
              v.get(title),
              page_text(v),
              v.get(comments),
              v.get(version),
              v.get(parent_title),
            )
          },
        ),
      ),
    ),
    (
      "delete",
      @schema.record([project_id.as_member(), title.as_member()], v => {
        WikiPageAction::Delete(v.get(project_id), v.get(title))
      }),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn wiki_pages_description(mode : Mode) -> String {
  let base = describe_crud_tool("wiki pages", mode)
  match mode {
    Readonly => base
    Full =>
      base +
      "\nFor a long page, `create` and `update` take `text_path`, the path of a local UTF-8 file, instead of `text` (absolute is recommended)."
  }
}

///|
/// `redmine_wiki_pages`: the wiki pages of a project. `Readonly` mode leaves
/// out create, update, and delete.
pub fn wiki_pages_tool(
  port : &WikiPagePort,
  files : &FilePort,
  mode : Mode,
) -> @mcp.Tool {
  text_file_tool(
    name="redmine_wiki_pages",
    description=wiki_pages_description(mode),
    input=wiki_pages_input(mode),
    files~,
    texts=[("create", "text"), ("update", "text")],
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
