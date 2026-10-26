///|
priv enum AgileAction {
  Get(Int32)
  Update(Int32, @agile.Update)
}

///|
fn agile_input(mode : Mode) -> @schema.Schema[AgileAction] {
  let issue_id = @schema.required("issue_id", record_id())
  let story_points = @schema.optional(
    "story_points",
    clearable(
      @schema.integer(min=0),
      "Estimate in story points, a whole number; `null` clears it.",
    ),
  )
  let agile_sprint_id = @schema.optional(
    "agile_sprint_id",
    clearable(
      record_id(),
      "Sprint to put the issue in; `null` takes it out of its sprint.",
    ),
  )
  let position = @schema.optional(
    "position",
    clearable(
      @schema.integer(),
      "Sort position of the issue's card on the agile board; `null` clears it.",
    ),
  )
  let read = [
    (
      "get",
      @schema.record([issue_id.as_member()], v => {
        AgileAction::Get(v.get(issue_id))
      }),
    ),
  ]
  let write = [
    (
      "update",
      @schema.record(
        [
          issue_id.as_member(),
          story_points.as_member(),
          agile_sprint_id.as_member(),
          position.as_member(),
        ],
        v => {
          AgileAction::Update(v.get(issue_id), {
            story_points: v.get(story_points),
            agile_sprint_id: v.get(agile_sprint_id),
            position: v.get(position),
          })
        },
      ),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn agile_description(mode : Mode) -> String {
  let subject = "the RedmineUP Agile data of one Redmine issue: its story points, its sprint, and the position of its card on the agile board."
  let requirement = "Needs the RedmineUP Agile plugin and the Agile module enabled on the issue's project: Redmine answers 404 for an issue without agile data and where the plugin is missing, and 403 where the module or the permission is missing."
  let lines = match mode {
    Readonly => ["Read \{subject}", requirement]
    Full =>
      [
        "Read and change \{subject}",
        "`update` changes only the fields it is given and keeps the others; `null` clears a field, which for `agile_sprint_id` takes the issue out of its sprint.",
        "A sprint is named by its id, which `get` shows as `agile_sprint_id` on an issue already in that sprint.",
        requirement,
      ]
  }
  [..lines, operation_key_hint].join("\n")
}

///|
/// `redmine_agile`: the per-issue data of the RedmineUP Agile plugin. `Readonly` mode leaves out `update`.
pub fn agile_tool(port : &AgilePort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_agile",
    description=agile_description(mode),
    input=agile_input(mode),
    handler=async fn(action) {
      match action {
        Get(issue_id) => respond(() => port.get_agile_data(issue_id))
        Update(issue_id, attributes) =>
          respond_ok(() => port.update_agile_data(issue_id, attributes))
      }
    },
  )
}
