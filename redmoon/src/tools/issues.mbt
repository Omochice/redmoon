///|
priv enum IssueAction {
  List(@issues.ListQuery, limit~ : Int32?)
  ListSaved(@issues.SavedQuery, limit~ : Int32?)
  ListQueries
  Show(Int32, includes~ : Array[@issues.Include], description_path~ : String?)
  Create(@issues.Create)
  Update(Int32, @issues.Update)
  Delete(Int32)
  UpdateNote(Int32, notes~ : String?, private_notes~ : Bool?)
  DeleteNote(Int32)
}

///|
fn list_includes() -> @schema.Schema[Array[@issues.ListInclude]] {
  @schema.array(
    @schema.choice([
      ("attachments", @issues.ListInclude::Attachments),
      ("relations", @issues.ListInclude::Relations),
    ]),
  ).describe(
    "Associations Redmine omits unless asked for. A listed issue carries only these two; `journals` are available through `show`.",
  )
}

///|
fn show_includes() -> @schema.Schema[Array[@issues.Include]] {
  @schema.array(
    @schema.choice([
      ("journals", @issues.Include::Journals),
      ("attachments", @issues.Include::Attachments),
      ("relations", @issues.Include::Relations),
      ("children", @issues.Include::Children),
      ("changesets", @issues.Include::Changesets),
      ("watchers", @issues.Include::Watchers),
      ("allowedStatuses", @issues.Include::AllowedStatuses),
    ]),
  ).describe(
    "Associations Redmine omits unless asked for. `journals` are the comments and the field-change history.",
  )
}

///|
fn status_filter() -> @schema.Schema[@issues.StatusFilter] {
  @schema.union([
    record_id().map(id => @issues.StatusFilter::Id(id)),
    @schema.choice([("open", Open), ("closed", Closed), ("*", All)]),
  ])
}

///|
fn assignee_filter() -> @schema.Schema[@issues.AssigneeFilter] {
  @schema.union([
    record_id().map(id => @issues.AssigneeFilter::User(id)),
    @schema.choice([("me", Me)]),
  ])
}

///|
/// Maps `null` to `Clear` so that a field Redmine can empty keeps "leave alone",
/// "empty" and "set" apart.
fn[T] clearable(
  schema : @schema.Schema[T],
  description : String,
) -> @schema.Schema[@redmine.Clearable[T]] {
  @schema.nullable(schema)
  .map(value => {
    match value {
      Some(value) => @redmine.Clearable::Set(value)
      None => Clear
    }
  })
  .describe(description)
}

///|
fn written_date_text(field : String, event : String, clearing : Bool) -> String {
  "Day the issue \{event}, as an ISO date (`YYYY-MM-DD`)\{if clearing { "; `null` clears the date" } else { "" }}. This is the date to write, not a filter: unlike `\{field}` on `list`, no period or range is accepted here."
}

///|
let custom_field_value : @schema.Schema[@issues.CustomFieldValue] = @schema.union([
    @schema.string().map(value => @issues.CustomFieldValue::Single(value)),
    @schema.array(@schema.string()).map(values => {
      @issues.CustomFieldValue::Multiple(values)
    }),
  ],
)

///|
let custom_fields_text : String = "Custom field values, each naming its field by id; `show` on an issue of the same project and tracker lists the fields and their ids under `custom_fields`. Every value is text, even for a number or checkbox field (`\"3\"`, `\"1\"` for checked), and a multi-value field takes an array of strings."

///|
let assignee_text : String = "User or group to assign the issue to, by the `user.id` or `group.id` that `redmine_memberships` lists for the project"

///|
fn custom_field_inputs(
  value : @schema.Schema[@issues.CustomFieldValue],
) -> @schema.Schema[Array[@issues.CustomFieldInput]] {
  let id = @schema.required("id", record_id())
  let value = @schema.required("value", value)
  @schema.array(
    @schema.record([id.as_member(), value.as_member()], v => @issues.CustomFieldInput::{
      id: v.get(id),
      value: v.get(value),
    }),
  )
}

///|
let issue_id : @schema.Field[Int32] = @schema.required("id", record_id())

///|
let list_include : @schema.Field[Array[@issues.ListInclude]?] = @schema.optional(
  "include",
  list_includes(),
)

///|
let list_limit : @schema.Field[Int32?] = @schema.optional(
  "limit",
  @schema.integer(min=1),
)

///|
let list_input : @schema.Schema[IssueAction] = {
  let project_id = @schema.optional("project_id", record_id())
  let tracker_id = @schema.optional("tracker_id", record_id())
  let status_id = @schema.optional("status_id", status_filter())
  let fixed_version_id = @schema.optional("fixed_version_id", record_id())
  let assigned_to_id = @schema.optional("assigned_to_id", assignee_filter())
  let start_date = @schema.optional("start_date", date_filter())
  let due_date = @schema.optional("due_date", date_filter())
  let created_on = @schema.optional("created_on", past_date_filter())
  let updated_on = @schema.optional("updated_on", past_date_filter())
  let closed_on = @schema.optional("closed_on", past_date_filter())
  @schema.record(
    [
      list_include.as_member(),
      project_id.as_member(),
      tracker_id.as_member(),
      status_id.as_member(),
      fixed_version_id.as_member(),
      assigned_to_id.as_member(),
      start_date.as_member(),
      due_date.as_member(),
      created_on.as_member(),
      updated_on.as_member(),
      closed_on.as_member(),
      list_limit.as_member(),
    ],
    v => {
      IssueAction::List(
        @issues.ListQuery::new(
          includes=v.get(list_include).unwrap_or([]),
          project_id?=v.get(project_id),
          tracker_id?=v.get(tracker_id),
          status_id?=v.get(status_id),
          fixed_version_id?=v.get(fixed_version_id),
          assigned_to_id?=v.get(assigned_to_id),
          start_date?=v.get(start_date),
          due_date?=v.get(due_date),
          created_on?=v.get(created_on),
          updated_on?=v.get(updated_on),
          closed_on?=v.get(closed_on),
        ),
        limit=v.get(list_limit),
      )
    },
  )
}

///|
let saved_list_input : @schema.Schema[IssueAction] = {
  let query_id = @schema.required(
    "query_id",
    record_id().describe(
      "Id of a saved query, as listed by `list_queries`. Redmine applies the query's own filters, so no filter can be added to this call, and a project query also needs its project as `project_id`.",
    ),
  )
  let project_id = @schema.optional(
    "project_id",
    record_id().describe(
      "Project to list the query's issues in. A project query, one `list_queries` lists with a `project_id`, needs exactly that project's id, and a subproject's id answers 404 just as leaving it out does. A global query is narrowed to the given project.",
    ),
  )
  let members = [
    query_id.as_member(),
    project_id.as_member(),
    list_include.as_member(),
    list_limit.as_member(),
  ]
  @schema.record(members, v => {
    IssueAction::ListSaved(
      @issues.SavedQuery::new(
        v.get(query_id),
        project_id?=v.get(project_id),
        includes=v.get(list_include).unwrap_or([]),
      ),
      limit=v.get(list_limit),
    )
  })
}

///|
let show_input : @schema.Schema[IssueAction] = {
  let includes = @schema.optional("include", show_includes())
  let description_path = save_path("description")
  let members = [
    issue_id.as_member(),
    includes.as_member(),
    description_path.as_member(),
  ]
  @schema.record(members, v => {
    IssueAction::Show(
      v.get(issue_id),
      includes=v.get(includes).unwrap_or([]),
      description_path=v.get(description_path),
    )
  })
}

///|
let create_input : @schema.Schema[IssueAction] = {
  let project_id = @schema.required("project_id", record_id())
  let tracker_id = @schema.required("tracker_id", record_id())
  let status_id = @schema.required("status_id", record_id())
  let priority_id = @schema.required("priority_id", record_id())
  let subject = @schema.required("subject", @schema.string())
  let description = @schema.optional("description", @schema.string())
  let description_path = text_path("description")
  let fixed_version_id = @schema.optional("fixed_version_id", record_id())
  let assigned_to_id = @schema.optional(
    "assigned_to_id",
    record_id().describe("\{assignee_text}."),
  )
  let parent_issue_id = @schema.optional("parent_issue_id", record_id())
  let start_date = @schema.optional(
    "start_date",
    @schema.iso_date().describe(
      written_date_text("start_date", "starts", false),
    ),
  )
  let due_date = @schema.optional(
    "due_date",
    @schema.iso_date().describe(written_date_text("due_date", "is due", false)),
  )
  let is_private = @schema.optional("is_private", @schema.boolean())
  let estimated_hours = @schema.optional("estimated_hours", @schema.number())
  let custom_fields = @schema.optional(
    "custom_fields",
    custom_field_inputs(custom_field_value).describe(custom_fields_text),
  )
  @schema.record(
    [
      project_id.as_member(),
      tracker_id.as_member(),
      status_id.as_member(),
      priority_id.as_member(),
      subject.as_member(),
      description.as_member(),
      description_path.as_member(),
      fixed_version_id.as_member(),
      assigned_to_id.as_member(),
      parent_issue_id.as_member(),
      start_date.as_member(),
      due_date.as_member(),
      is_private.as_member(),
      estimated_hours.as_member(),
      custom_fields.as_member(),
    ],
    v => {
      IssueAction::Create(
        @issues.Create::new(
          project_id=v.get(project_id),
          tracker_id=v.get(tracker_id),
          status_id=v.get(status_id),
          priority_id=v.get(priority_id),
          subject=v.get(subject),
          description?=v.get(description),
          fixed_version_id?=v.get(fixed_version_id),
          assigned_to_id?=v.get(assigned_to_id),
          parent_issue_id?=v.get(parent_issue_id),
          is_private?=v.get(is_private),
          estimated_hours?=v.get(estimated_hours),
          start_date?=v.get(start_date),
          due_date?=v.get(due_date),
          custom_fields?=v.get(custom_fields),
        ),
      )
    },
  )
}

///|
let update_input : @schema.Schema[IssueAction] = {
  let subject = @schema.optional("subject", @schema.string())
  let description = @schema.optional("description", @schema.string())
  let description_path = text_path("description")
  let status_id = @schema.optional(
    "status_id",
    record_id().describe(
      "Status to move the issue to. Redmine ignores, without an error, a status the workflow does not allow; `show` with `include: [\"allowedStatuses\"]` lists the ones it does.",
    ),
  )
  let priority_id = @schema.optional("priority_id", record_id())
  let tracker_id = @schema.optional("tracker_id", record_id())
  let assigned_to_id = @schema.optional(
    "assigned_to_id",
    clearable(record_id(), "\{assignee_text}; `null` unassigns it."),
  )
  let category_id = @schema.optional(
    "category_id",
    clearable(
      record_id(),
      "Issue category to file the issue under; `null` removes the category.",
    ),
  )
  let parent_issue_id = @schema.optional(
    "parent_issue_id",
    clearable(
      record_id(),
      "Issue to make the parent of this one; `null` detaches it from its parent.",
    ),
  )
  let fixed_version_id = @schema.optional(
    "fixed_version_id",
    clearable(
      record_id(),
      "Version to move the issue into; `null` takes it out of its version.",
    ),
  )
  let start_date = @schema.optional(
    "start_date",
    clearable(
      @schema.iso_date(),
      written_date_text("start_date", "starts", true),
    ),
  )
  let due_date = @schema.optional(
    "due_date",
    clearable(@schema.iso_date(), written_date_text("due_date", "is due", true)),
  )
  let done_ratio = @schema.optional(
    "done_ratio",
    @schema.integer(min=0, max=100),
  )
  let is_private = @schema.optional("is_private", @schema.boolean())
  let estimated_hours = @schema.optional("estimated_hours", @schema.number())
  let notes = @schema.optional("notes", @schema.string())
  let notes_path = text_path("notes")
  let private_notes = @schema.optional("private_notes", @schema.boolean())
  let custom_fields = @schema.optional(
    "custom_fields",
    custom_field_inputs(
      @schema.nullable(custom_field_value).map(value => {
        value.unwrap_or(@issues.CustomFieldValue::Single(""))
      }),
    ).describe(
      custom_fields_text +
      " `null` empties a field, and a field left out keeps its value.",
    ),
  )
  @schema.record(
    [
      issue_id.as_member(),
      subject.as_member(),
      description.as_member(),
      description_path.as_member(),
      status_id.as_member(),
      priority_id.as_member(),
      tracker_id.as_member(),
      assigned_to_id.as_member(),
      category_id.as_member(),
      parent_issue_id.as_member(),
      fixed_version_id.as_member(),
      start_date.as_member(),
      due_date.as_member(),
      done_ratio.as_member(),
      is_private.as_member(),
      estimated_hours.as_member(),
      notes.as_member(),
      notes_path.as_member(),
      private_notes.as_member(),
      custom_fields.as_member(),
    ],
    v => {
      IssueAction::Update(
        v.get(issue_id),
        @issues.Update::new(
          subject?=v.get(subject),
          description?=v.get(description),
          notes?=v.get(notes),
          private_notes?=v.get(private_notes),
          done_ratio?=v.get(done_ratio),
          is_private?=v.get(is_private),
          estimated_hours?=v.get(estimated_hours),
          status_id?=v.get(status_id),
          priority_id?=v.get(priority_id),
          tracker_id?=v.get(tracker_id),
          assigned_to_id?=v.get(assigned_to_id),
          category_id?=v.get(category_id),
          parent_issue_id?=v.get(parent_issue_id),
          fixed_version_id?=v.get(fixed_version_id),
          start_date?=v.get(start_date),
          due_date?=v.get(due_date),
          custom_fields?=v.get(custom_fields),
        ),
      )
    },
  )
}

///|
let delete_input : @schema.Schema[IssueAction] = @schema.record(
  [issue_id.as_member()],
  v => IssueAction::Delete(v.get(issue_id)),
)

///|
let journal : @schema.Field[Int32] = @schema.required(
  "journal_id",
  record_id().describe(
    "Id of the comment (journal), as listed by `show` with `include: [\"journals\"]`.",
  ),
)

///|
let private_notes_required : @schema.Field[Bool] = @schema.required(
  "private_notes",
  @schema.boolean(),
)

///|
/// Split from the visibility shape because the advertised JSON Schema cannot
/// require "at least one of `notes` and `private_notes`" on a single object.
let update_note_text_input : @schema.Schema[IssueAction] = {
  let notes = @schema.required(
    "notes",
    @schema.not_blank().describe(
      "New text of the comment. To erase it, use `delete_note`.",
    ),
  )
  let private_notes = @schema.optional("private_notes", @schema.boolean())
  @schema.record(
    [journal.as_member(), notes.as_member(), private_notes.as_member()],
    v => {
      IssueAction::UpdateNote(
        v.get(journal),
        notes=Some(v.get(notes)),
        private_notes=v.get(private_notes),
      )
    },
  )
}

///|
let update_note_file_input : @schema.Schema[IssueAction] = {
  let notes_path = @schema.required(
    "notes_path",
    path_schema(text_path_text("notes")),
  )
  let private_notes = @schema.optional("private_notes", @schema.boolean())
  @schema.record(
    [journal.as_member(), notes_path.as_member(), private_notes.as_member()],
    // Only the validation before reading the file reaches this shape; the
    // file then turns `notes_path` into `notes`, which selects the text shape.
    v => {
      ignore(v.get(notes_path))
      IssueAction::UpdateNote(
        v.get(journal),
        notes=None,
        private_notes=v.get(private_notes),
      )
    },
  )
}

///|
let update_note_visibility_input : @schema.Schema[IssueAction] = @schema.record(
  [journal.as_member(), private_notes_required.as_member()],
  v => {
    IssueAction::UpdateNote(
      v.get(journal),
      notes=None,
      private_notes=Some(v.get(private_notes_required)),
    )
  },
)

///|
let delete_note_input : @schema.Schema[IssueAction] = @schema.record(
  [journal.as_member()],
  v => IssueAction::DeleteNote(v.get(journal)),
)

///|
fn issues_input(mode : Mode) -> @schema.Schema[IssueAction] {
  let read = [
    (
      "list",
      @schema.by_key([("query_id", saved_list_input)], otherwise=list_input),
    ),
    ("list_queries", @schema.record([], _ => IssueAction::ListQueries)),
    ("show", show_input),
  ]
  let write = [
    ("create", exclusive_text(create_input, field="description")),
    (
      "update",
      exclusive_text(
        exclusive_text(update_input, field="description"),
        field="notes",
      ),
    ),
    ("delete", delete_input),
    (
      "update_note",
      @schema.by_key([
        ("notes", update_note_text_input),
        ("notes_path", update_note_file_input),
        ("private_notes", update_note_visibility_input),
      ]),
    ),
    ("delete_note", delete_note_input),
  ]
  actions(mode, read~, write~)
}

///|
fn issues_description(mode : Mode) -> String {
  let base = [
    describe_crud_tool("issues", mode),
    "`show` returns the bare issue; pass `include: [\"journals\"]` to get its comments and field-change history, and add `attachments`, `relations`, `children`, `changesets`, `watchers`, or `allowedStatuses` as needed.",
    "`list` accepts only `attachments` and `relations`.",
    "`list` takes either filters or the `query_id` of a saved query that `list_queries` lists, never both.",
    "A saved query listed with a `project_id` belongs to that project and must be used with exactly that `project_id`; without it, or with a subproject's id, Redmine answers 404.",
    "`show` with `description_path` saves the description to a new local file and answers with that path instead of the text.",
  ]
  match mode {
    Readonly => base.join("\n")
    Full =>
      [
        ..base, "`update_note` edits the text or privacy of an existing comment, and `delete_note` erases its text; both take the journal id that `show` lists.",
        "For a long text, pass the path of a local UTF-8 file instead of the text itself: `description_path` on `create` and `update`, and `notes_path` on `update` and `update_note` (absolute is recommended).",
      ].join("\n")
  }
}

///|
/// `redmine_issues`: list, show, create, update and delete issues, list the
/// saved queries that select them, and edit their comments. `Readonly` keeps `list`, `list_queries` and `show`.
pub fn issues_tool(
  port : &IssuePort,
  files : &FilePort,
  mode : Mode,
) -> @mcp.Tool {
  text_file_tool(
    name="redmine_issues",
    description=issues_description(mode),
    input=issues_input(mode),
    files~,
    texts=[
      ("create", "description"),
      ("update", "description"),
      ("update", "notes"),
      ("update_note", "notes"),
    ],
    handler=async fn(action) {
      match action {
        List(query, limit~) => respond(() => port.list_issues(query, limit))
        ListSaved(query, limit~) =>
          respond(() => port.list_saved_issues(query, limit))
        ListQueries => respond(() => port.list_queries())
        Show(id, includes~, description_path~) => {
          let issue = port.show_issue(id, includes) catch {
            error => return failure_of(error)
          }
          let description = issue.description.unwrap_or("")
          respond_saving_text(
            files,
            issue.to_json(),
            "description",
            description,
            description_path,
          )
        }
        Create(issue) => respond(() => port.create_issue(issue))
        Update(id, update) => respond_ok(() => port.update_issue(id, update))
        Delete(id) => respond_ok(() => port.delete_issue(id))
        UpdateNote(id, notes~, private_notes~) =>
          respond_ok(() => port.update_journal(id, notes, private_notes))
        DeleteNote(id) =>
          respond_ok(() => port.update_journal(id, Some(""), None))
      }
    },
  )
}
