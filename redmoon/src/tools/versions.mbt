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
  let read = [
    (
      "list",
      @schema.object(p => VersionAction::List(p))
      |> @schema.field("project_id", project_ref())
      |> @schema.Obj::done,
    ),
    (
      "show",
      @schema.object(id => VersionAction::Show(id))
      |> @schema.field("id", record_id())
      |> @schema.Obj::done,
    ),
  ]
  let write = [
    (
      "create",
      @schema.object(p => {
        name => {
          description => {
            status => {
              due_date => {
                sharing => {
                  wiki_page_title => {
                    VersionAction::Create(p, {
                      name,
                      description,
                      status,
                      due_date,
                      sharing,
                      wiki_page_title,
                    })
                  }
                }
              }
            }
          }
        }
      })
      |> @schema.field("project_id", project_ref())
      |> @schema.field("name", @schema.string())
      |> @schema.optional("description", @schema.string())
      |> @schema.optional("status", version_status())
      |> @schema.optional("due_date", @schema.iso_date())
      |> @schema.optional("sharing", version_sharing())
      |> @schema.optional("wiki_page_title", @schema.string())
      |> @schema.Obj::done,
    ),
    (
      "update",
      @schema.object(id => {
        name => {
          description => {
            status => {
              due_date => {
                sharing => {
                  wiki_page_title => {
                    VersionAction::Update(id, {
                      name,
                      description,
                      status,
                      due_date,
                      sharing,
                      wiki_page_title,
                    })
                  }
                }
              }
            }
          }
        }
      })
      |> @schema.field("id", record_id())
      |> @schema.optional("name", @schema.string())
      |> @schema.optional("description", @schema.string())
      |> @schema.optional("status", version_status())
      |> @schema.optional("due_date", @schema.iso_date())
      |> @schema.optional("sharing", version_sharing())
      |> @schema.optional("wiki_page_title", @schema.string())
      |> @schema.Obj::done,
    ),
    (
      "delete",
      @schema.object(id => VersionAction::Delete(id))
      |> @schema.field("id", record_id())
      |> @schema.Obj::done,
    ),
  ]
  match mode {
    Full => @schema.keyed([..read, ..write])
    Readonly => @schema.keyed(read)
  }
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
