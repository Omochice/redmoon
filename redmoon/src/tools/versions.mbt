///|
priv enum VersionAction {
  List(@redmine.ProjectRef)
  Show(Int32)
  Create(@redmine.ProjectRef, @versions.Create)
  Update(Int32, @versions.Update)
  Delete(Int32)
}

///|
fn version_status() -> @schema.Schema[@versions.Status] {
  @schema.choice([
    ("open", @versions.Status::Open),
    ("locked", Locked),
    ("closed", Closed),
  ])
}

///|
fn version_sharing() -> @schema.Schema[@versions.Sharing] {
  @schema.choice([
    ("none", @versions.Sharing::None),
    ("descendants", Descendants),
    ("hierarchy", Hierarchy),
    ("tree", Tree),
    ("system", System),
  ])
}

///|
fn versions_input(mode : Mode) -> @schema.Schema[VersionAction] {
  let project_id = @schema.required("project_id", project_ref())
  let id = @schema.required("id", record_id())
  let name_schema = @schema.not_blank(max_length=60).describe(
    "Name of the version, unique within its project.",
  )
  let name = @schema.optional("name", name_schema)
  let description_schema = @schema.string(max_length=255)
  let description = @schema.optional(
    "description",
    description_schema.describe("Free text shown on the version's page."),
  )
  let clear_description = @schema.optional(
    "description",
    clearable(
      description_schema, "Free text shown on the version's page; `null` empties it.",
    ),
  )
  let status = @schema.optional(
    "status",
    version_status().describe(
      "`open` accepts new issues, `locked` refuses them while keeping the version listed, and `closed` ends it.",
    ),
  )
  let due_date = @schema.optional(
    "due_date",
    @schema.iso_date().describe(
      "Day the version is due, as an ISO date (`YYYY-MM-DD`).",
    ),
  )
  let clear_due_date = @schema.optional(
    "due_date",
    clearable(
      @schema.iso_date(),
      "Day the version is due, as an ISO date (`YYYY-MM-DD`); `null` clears it.",
    ),
  )
  let sharing = @schema.optional(
    "sharing",
    version_sharing().describe(
      "Which other projects can assign issues to the version: `none`, the project's `descendants`, its `hierarchy` (ancestors and descendants), its whole `tree`, or `system` for every project.",
    ),
  )
  let wiki_page_title_schema = @schema.string(max_length=255)
  let wiki_page_title = @schema.optional(
    "wiki_page_title",
    wiki_page_title_schema.describe(
      "Title of the wiki page in the same project that the version links to.",
    ),
  )
  let clear_wiki_page_title = @schema.optional(
    "wiki_page_title",
    clearable(
      wiki_page_title_schema, "Title of the wiki page in the same project that the version links to; `null` unlinks it.",
    ),
  )
  let create_name = @schema.required("name", name_schema)
  let read = [
    (
      "list",
      @schema.record([project_id.as_member()], v => {
        VersionAction::List(v.get(project_id))
      }),
    ),
    (
      "show",
      @schema.record([id.as_member()], v => VersionAction::Show(v.get(id))),
    ),
  ]
  let write = [
    (
      "create",
      @schema.record(
        [
          project_id.as_member(),
          create_name.as_member(),
          description.as_member(),
          status.as_member(),
          due_date.as_member(),
          sharing.as_member(),
          wiki_page_title.as_member(),
        ],
        v => {
          VersionAction::Create(
            v.get(project_id),
            @versions.Create::new(
              name=v.get(create_name),
              description?=v.get(description),
              status?=v.get(status),
              due_date?=v.get(due_date),
              sharing?=v.get(sharing),
              wiki_page_title?=v.get(wiki_page_title),
            ),
          )
        },
      ),
    ),
    (
      "update",
      @schema.record(
        [
          id.as_member(),
          name.as_member(),
          clear_description.as_member(),
          status.as_member(),
          clear_due_date.as_member(),
          sharing.as_member(),
          clear_wiki_page_title.as_member(),
        ],
        v => {
          VersionAction::Update(
            v.get(id),
            @versions.Update::new(
              name?=v.get(name),
              description?=v.get(clear_description),
              status?=v.get(status),
              due_date?=v.get(clear_due_date),
              sharing?=v.get(sharing),
              wiki_page_title?=v.get(clear_wiki_page_title),
            ),
          )
        },
      ),
    ),
    (
      "delete",
      @schema.record([id.as_member()], v => VersionAction::Delete(v.get(id))),
    ),
  ]
  actions(mode, read~, write~)
}

///|
/// `redmine_versions`: the versions (milestones) of a project.
/// `Readonly` mode leaves out create, update, and delete.
pub fn versions_tool(port : &VersionPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_versions",
    description=describe_crud_tool("project versions (milestones)", mode),
    input=versions_input(mode),
    handler=async fn(action) {
      match action {
        List(project) => respond(() => port.list_versions(project))
        Show(id) => respond(() => port.show_version(id))
        Create(project, attributes) =>
          respond(() => port.create_version(project, attributes))
        Update(id, attributes) =>
          respond_ok(() => port.update_version(id, attributes))
        Delete(id) => respond_ok(() => port.delete_version(id))
      }
    },
  )
}
