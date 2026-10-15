///|
priv enum IssueAction {
  List(@redmine.IssueListQuery, limit~ : Int32?)
  Show(Int32, includes~ : Array[@redmine.IssueInclude])
  Create(@redmine.IssueCreate)
  Update(Int32, @redmine.IssueUpdate)
  Delete(Int32)
  UpdateNote(Int32, notes~ : String?, private_notes~ : Bool?)
  DeleteNote(Int32)
}

///|
fn list_includes() -> @schema.Schema[Array[@redmine.IssueListInclude]] {
  @schema.array(
    @schema.choice([
      ("attachments", @redmine.IssueListInclude::Attachments),
      ("relations", @redmine.IssueListInclude::Relations),
    ]),
  ).describe(
    "Associations Redmine omits unless asked for. A listed issue carries only these two; `journals` are available through `show`.",
  )
}

///|
fn show_includes() -> @schema.Schema[Array[@redmine.IssueInclude]] {
  @schema.array(
    @schema.choice([
      ("journals", @redmine.IssueInclude::Journals),
      ("attachments", @redmine.IssueInclude::Attachments),
      ("relations", @redmine.IssueInclude::Relations),
      ("children", @redmine.IssueInclude::Children),
      ("changesets", @redmine.IssueInclude::Changesets),
      ("watchers", @redmine.IssueInclude::Watchers),
      ("allowedStatuses", @redmine.IssueInclude::AllowedStatuses),
    ]),
  ).describe(
    "Associations Redmine omits unless asked for. `journals` are the comments and the field-change history.",
  )
}

///|
fn status_filter() -> @schema.Schema[@redmine.StatusFilter] {
  @schema.union([
    record_id().map(id => @redmine.StatusFilter::Id(id)),
    @schema.choice([("open", Open), ("closed", Closed), ("*", All)]),
  ])
}

///|
fn assignee_filter() -> @schema.Schema[@redmine.AssigneeFilter] {
  @schema.union([
    record_id().map(id => @redmine.AssigneeFilter::User(id)),
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
fn written_date(description : String) -> @schema.Schema[String] {
  @schema.iso_date().describe(description)
}

///|
fn start_date_text(clearing : Bool) -> String {
  "Day the issue starts, as an ISO date (`YYYY-MM-DD`)\{if clearing { "; `null` clears the date" } else { "" }}. This is the date to write, not a filter: unlike `start_date` on `list`, no period or range is accepted here."
}

///|
fn due_date_text(clearing : Bool) -> String {
  "Day the issue is due, as an ISO date (`YYYY-MM-DD`)\{if clearing { "; `null` clears the date" } else { "" }}. This is the date to write, not a filter: unlike `due_date` on `list`, no period or range is accepted here."
}

///|
let issue_id : @schema.Field[Int32] = @schema.required("id", record_id())

///|
let list_input : @schema.Schema[IssueAction] = {
  let includes = @schema.optional_field("include", list_includes())
  let project_id = @schema.optional_field("project_id", record_id())
  let tracker_id = @schema.optional_field("tracker_id", record_id())
  let status_id = @schema.optional_field("status_id", status_filter())
  let fixed_version_id = @schema.optional_field("fixed_version_id", record_id())
  let assigned_to_id = @schema.optional_field(
    "assigned_to_id",
    assignee_filter(),
  )
  let start_date = @schema.optional_field("start_date", date_filter())
  let due_date = @schema.optional_field("due_date", date_filter())
  let created_on = @schema.optional_field("created_on", past_date_filter())
  let updated_on = @schema.optional_field("updated_on", past_date_filter())
  let closed_on = @schema.optional_field("closed_on", past_date_filter())
  let limit = @schema.optional_field("limit", @schema.integer())
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
        @redmine.IssueListQuery::new(
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
  let includes = @schema.optional_field("include", show_includes())
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
  let description = @schema.optional_field("description", @schema.string())
  let fixed_version_id = @schema.optional_field("fixed_version_id", record_id())
  let assigned_to_id = @schema.optional_field("assigned_to_id", record_id())
  let parent_issue_id = @schema.optional_field("parent_issue_id", record_id())
  let start_date = @schema.optional_field(
    "start_date",
    written_date(start_date_text(false)),
  )
  let due_date = @schema.optional_field(
    "due_date",
    written_date(due_date_text(false)),
  )
  let is_private = @schema.optional_field("is_private", @schema.boolean())
  let estimated_hours = @schema.optional_field(
    "estimated_hours",
    @schema.number(),
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
    ],
    v => {
      IssueAction::Create(
        @redmine.IssueCreate::new(
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
        ),
      )
    },
  )
}

///|
let update_input : @schema.Schema[IssueAction] = {
  let subject = @schema.optional_field("subject", @schema.string())
  let description = @schema.optional_field("description", @schema.string())
  let status_id = @schema.optional_field(
    "status_id",
    record_id().describe(
      "Status to move the issue to. Redmine ignores, without an error, a status the workflow does not allow; `show` with `include: [\"allowedStatuses\"]` lists the ones it does.",
    ),
  )
  let priority_id = @schema.optional_field("priority_id", record_id())
  let tracker_id = @schema.optional_field("tracker_id", record_id())
  let assigned_to_id = @schema.optional_field(
    "assigned_to_id",
    clearable(record_id(), "User to assign the issue to; `null` unassigns it."),
  )
  let category_id = @schema.optional_field(
    "category_id",
    clearable(
      record_id(),
      "Issue category to file the issue under; `null` removes the category.",
    ),
  )
  let parent_issue_id = @schema.optional_field(
    "parent_issue_id",
    clearable(
      record_id(),
      "Issue to make the parent of this one; `null` detaches it from its parent.",
    ),
  )
  let fixed_version_id = @schema.optional_field(
    "fixed_version_id",
    clearable(
      record_id(),
      "Version to move the issue into; `null` takes it out of its version.",
    ),
  )
  let start_date = @schema.optional_field(
    "start_date",
    clearable(@schema.iso_date(), start_date_text(true)),
  )
  let due_date = @schema.optional_field(
    "due_date",
    clearable(@schema.iso_date(), due_date_text(true)),
  )
  let done_ratio = @schema.optional_field("done_ratio", @schema.integer())
  let is_private = @schema.optional_field("is_private", @schema.boolean())
  let estimated_hours = @schema.optional_field(
    "estimated_hours",
    @schema.number(),
  )
  let notes = @schema.optional_field("notes", @schema.string())
  let private_notes = @schema.optional_field("private_notes", @schema.boolean())
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
    ],
    v => {
      IssueAction::Update(
        v.get(issue_id),
        @redmine.IssueUpdate::new(
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
fn journal_id() -> @schema.Schema[Int32] {
  record_id().describe(
    "Id of the comment (journal), as listed by `show` with `include: [\"journals\"]`.",
  )
}

///|
let journal : @schema.Field[Int32] = @schema.required(
  "journal_id",
  journal_id(),
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
  let private_notes = @schema.optional_field("private_notes", @schema.boolean())
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
  match mode {
    Readonly => @schema.keyed(read)
    Full =>
      @schema.keyed(
        [
          ..read,
          ("create", create_input),
          ("update", update_input),
          ("delete", delete_input),
          ("update_note", update_note_text_input),
          ("update_note", update_note_visibility_input),
          ("delete_note", delete_note_input),
        ],
      )
  }
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
