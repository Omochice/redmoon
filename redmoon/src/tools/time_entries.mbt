///|
priv enum TimeEntryAction {
  ListEntries(@redmine.TimeEntryListQuery)
  ShowEntry(Int32)
  CreateEntry(@redmine.TimeEntryCreate)
  UpdateEntry(Int32, @redmine.TimeEntryUpdate)
  DeleteEntry(Int32)
}

///|
let time_entry_list_input : @schema.Schema[TimeEntryAction] = @schema.object(project_id => {
    user_id => {
      spent_on => {
        from => to => ListEntries({ project_id, user_id, spent_on, from, to, })
      }
    }
  })
  |> @schema.optional("project_id", record_id())
  |> @schema.optional("user_id", record_id())
  |> @schema.optional("spent_on", @schema.iso_date())
  |> @schema.optional("from", @schema.iso_date())
  |> @schema.optional("to", @schema.iso_date())
  |> @schema.Obj::done

///|
let time_entry_show_input : @schema.Schema[TimeEntryAction] = @schema.object(id => {
    ShowEntry(id)
  })
  |> @schema.field("id", record_id())
  |> @schema.Obj::done

///|
let time_entry_create_input : @schema.Schema[TimeEntryAction] = @schema.object(hours => {
    issue_id => {
      project_id => {
        spent_on => {
          activity_id => {
            comments => {
              CreateEntry({
                hours,
                issue_id,
                project_id,
                spent_on,
                activity_id,
                comments,
              })
            }
          }
        }
      }
    }
  })
  |> @schema.field("hours", @schema.number())
  |> @schema.optional("issue_id", record_id())
  |> @schema.optional("project_id", record_id())
  |> @schema.optional("spent_on", @schema.iso_date())
  |> @schema.optional("activity_id", record_id())
  |> @schema.optional("comments", @schema.string())
  |> @schema.Obj::done

///|
let time_entry_update_input : @schema.Schema[TimeEntryAction] = @schema.object(id => {
    hours => {
      issue_id => {
        project_id => {
          spent_on => {
            activity_id => {
              comments => {
                UpdateEntry(id, {
                  hours,
                  issue_id,
                  project_id,
                  spent_on,
                  activity_id,
                  comments,
                })
              }
            }
          }
        }
      }
    }
  })
  |> @schema.field("id", record_id())
  |> @schema.optional("hours", @schema.number())
  |> @schema.optional("issue_id", record_id())
  |> @schema.optional("project_id", record_id())
  |> @schema.optional("spent_on", @schema.iso_date())
  |> @schema.optional("activity_id", record_id())
  |> @schema.optional("comments", @schema.string())
  |> @schema.Obj::done

///|
let time_entry_delete_input : @schema.Schema[TimeEntryAction] = @schema.object(id => {
    DeleteEntry(id)
  })
  |> @schema.field("id", record_id())
  |> @schema.Obj::done

///|
/// Readonly drops the write actions so a write is inexpressible in the schema
/// rather than rejected after parsing.
fn time_entry_input(mode : Mode) -> @schema.Schema[TimeEntryAction] {
  let read = [("list", time_entry_list_input), ("show", time_entry_show_input)]
  let write = [
    ("create", time_entry_create_input),
    ("update", time_entry_update_input),
    ("delete", time_entry_delete_input),
  ]
  @schema.keyed(
    match mode {
      Full => [..read, ..write]
      Readonly => read
    },
  )
}

///|
/// `redmine_time_entries`: the time logged against issues and projects.
pub fn time_entries_tool(port : &TimeEntryPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_time_entries",
    description=describe_crud_tool("time entries", mode),
    input=time_entry_input(mode),
    handler=async fn(action) {
      match action {
        ListEntries(query) => respond(() => port.list_time_entries(query))
        ShowEntry(id) => respond(() => port.show_time_entry(id))
        CreateEntry(time_entry) =>
          respond(() => port.create_time_entry(time_entry))
        UpdateEntry(id, time_entry) =>
          respond_ok(() => port.update_time_entry(id, time_entry))
        DeleteEntry(id) => respond_ok(() => port.delete_time_entry(id))
      }
    },
  )
}
