///|
priv enum IssueAction {
  List(@issues.ListQuery, limit~ : Int32?)
  Show(Int32, includes~ : Array[@issues.Include])
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
let list_input : @schema.Schema[IssueAction] = {
  let includes = @schema.optional("include", list_includes())
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
  let limit = @schema.optional("limit", @schema.integer(min=1))
  @schema.record(
    [
      includes.as_member(),
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
      limit.as_member(),
    ],
    v => {
      IssueAction::List(
        @issues.ListQuery::new(
          includes=v.get(includes).unwrap_or([]),
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
        limit=v.get(limit),
      )
    },
  )
}

///|
let show_input : @schema.Schema[IssueAction] = {
  let includes = @schema.optional("include", show_includes())
  @schema.record([issue_id.as_member(), includes.as_member()], v => {
    IssueAction::Show(v.get(issue_id), includes=v.get(includes).unwrap_or([]))
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
  let fixed_version_id = @schema.optional("fixed_version_id", record_id())
  let assigned_to_id = @schema.optional("assigned_to_id", record_id())
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
    clearable(record_id(), "User to assign the issue to; `null` unassigns it."),
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
/// "At least one of `notes` and `private_notes`" is two alternatives of one
/// action, because the advertised JSON Schema cannot state it as a check on a
/// single object. The second has no `notes` field, so a call whose `notes` is
/// not valid text is rejected instead of falling through and losing it.
let update_note_text_input : @schema.Schema[IssueAction] = {
  let notes = @schema.required(
    "notes",
    @schema.string(min_length=1).describe(
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
  let read = [("list", list_input), ("show", show_input)]
  let write = [
    ("create", create_input),
    ("update", update_input),
    ("delete", delete_input),
    ("update_note", update_note_text_input),
    ("update_note", update_note_visibility_input),
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
  ]
  match mode {
    Readonly => base.join("\n")
    Full =>
      [
        ..base, "`update_note` edits the text or privacy of an existing comment, and `delete_note` erases its text; both take the journal id that `show` lists.",
      ].join("\n")
  }
}

///|
/// `redmine_issues`: list, show, create, update and delete issues, and edit
/// their comments. `Readonly` keeps `list` and `show`.
pub fn issues_tool(port : &IssuePort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_issues",
    description=issues_description(mode),
    input=issues_input(mode),
    handler=async fn(action) {
      match action {
        List(query, limit~) => respond(() => port.list_issues(query, limit))
        Show(id, includes~) => respond(() => port.show_issue(id, includes))
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
