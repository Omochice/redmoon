///|
priv enum VersionAction {
  List(@redmine.ProjectRef)
  Show(Int32)
  Create(@redmine.ProjectRef, @redmine.VersionCreate)
  Update(Int32, @redmine.VersionUpdate)
  Delete(Int32)
}

///|
fn version_status() -> @schema.Schema[@redmine.VersionStatus] {
  @schema.choice([
    ("open", @redmine.VersionStatus::Open),
    ("locked", Locked),
    ("closed", Closed),
  ])
}

///|
fn version_sharing() -> @schema.Schema[@redmine.VersionSharing] {
  @schema.choice([
    ("none", @redmine.VersionSharing::None),
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
  let name = @schema.optional("name", @schema.string())
  let description = @schema.optional("description", @schema.string())
  let status = @schema.optional("status", version_status())
  let due_date = @schema.optional("due_date", @schema.iso_date())
  let sharing = @schema.optional("sharing", version_sharing())
  let wiki_page_title = @schema.optional("wiki_page_title", @schema.string())
  let create_name = @schema.required("name", @schema.string())
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
          VersionAction::Create(v.get(project_id), {
            name: v.get(create_name),
            description: v.get(description),
            status: v.get(status),
            due_date: v.get(due_date),
            sharing: v.get(sharing),
            wiki_page_title: v.get(wiki_page_title),
          })
        },
      ),
    ),
    (
      "update",
      @schema.record(
        [
          id.as_member(),
          name.as_member(),
          description.as_member(),
          status.as_member(),
          due_date.as_member(),
          sharing.as_member(),
          wiki_page_title.as_member(),
        ],
        v => {
          VersionAction::Update(v.get(id), {
            name: v.get(name),
            description: v.get(description),
            status: v.get(status),
            due_date: v.get(due_date),
            sharing: v.get(sharing),
            wiki_page_title: v.get(wiki_page_title),
          })
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
/// `redmine_versions`: the versions (milestones) of a project. `Readonly` mode
/// leaves out create, update, and delete.
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
