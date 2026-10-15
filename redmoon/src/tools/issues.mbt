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
let list_input : @schema.Schema[IssueAction] = @schema.object(
    
    includes =>
    project_id =>
    tracker_id =>
    status_id =>
    fixed_version_id =>
    assigned_to_id =>
    start_date =>
    due_date =>
    created_on =>
    updated_on =>
    closed_on =>
    limit => {
      IssueAction::List(
        @redmine.IssueListQuery::new(
          includes=includes.unwrap_or([]),
          project_id?,
          tracker_id?,
          status_id?,
          fixed_version_id?,
          assigned_to_id?,
          start_date?,
          due_date?,
          created_on?,
          updated_on?,
          closed_on?,
        ),
        limit~,
      )
    },
  )
  |> @schema.optional("include", list_includes())
  |> @schema.optional("project_id", record_id())
  |> @schema.optional("tracker_id", record_id())
  |> @schema.optional("status_id", status_filter())
  |> @schema.optional("fixed_version_id", record_id())
  |> @schema.optional("assigned_to_id", assignee_filter())
  |> @schema.optional("start_date", date_filter())
  |> @schema.optional("due_date", date_filter())
  |> @schema.optional("created_on", past_date_filter())
  |> @schema.optional("updated_on", past_date_filter())
  |> @schema.optional("closed_on", past_date_filter())
  |> @schema.optional("limit", @schema.integer())
  |> @schema.Obj::done

///|
let show_input : @schema.Schema[IssueAction] = @schema.object(id => {
    includes => IssueAction::Show(id, includes=includes.unwrap_or([]))
  })
  |> @schema.field("id", record_id())
  |> @schema.optional("include", show_includes())
  |> @schema.Obj::done

///|
let create_input : @schema.Schema[IssueAction] = @schema.object(
    
    project_id =>
    tracker_id =>
    status_id =>
    priority_id =>
    subject =>
    description =>
    fixed_version_id =>
    assigned_to_id =>
    parent_issue_id =>
    start_date =>
    due_date =>
    is_private =>
    estimated_hours => {
      IssueAction::Create(
        @redmine.IssueCreate::new(
          project_id~,
          tracker_id~,
          status_id~,
          priority_id~,
          subject~,
          description?,
          fixed_version_id?,
          assigned_to_id?,
          parent_issue_id?,
          is_private?,
          estimated_hours?,
          start_date?,
          due_date?,
        ),
      )
    },
  )
  |> @schema.field("project_id", record_id())
  |> @schema.field("tracker_id", record_id())
  |> @schema.field("status_id", record_id())
  |> @schema.field("priority_id", record_id())
  |> @schema.field("subject", @schema.string())
  |> @schema.optional("description", @schema.string())
  |> @schema.optional("fixed_version_id", record_id())
  |> @schema.optional("assigned_to_id", record_id())
  |> @schema.optional("parent_issue_id", record_id())
  |> @schema.optional("start_date", written_date(start_date_text(false)))
  |> @schema.optional("due_date", written_date(due_date_text(false)))
  |> @schema.optional("is_private", @schema.boolean())
  |> @schema.optional("estimated_hours", @schema.number())
  |> @schema.Obj::done

///|
let update_input : @schema.Schema[IssueAction] = @schema.object(
    
    id =>
    subject =>
    description =>
    status_id =>
    priority_id =>
    tracker_id =>
    assigned_to_id =>
    category_id =>
    parent_issue_id =>
    fixed_version_id =>
    start_date =>
    due_date =>
    done_ratio =>
    is_private =>
    estimated_hours =>
    notes =>
    private_notes => {
      IssueAction::Update(
        id,
        @redmine.IssueUpdate::new(
          subject?,
          description?,
          notes?,
          private_notes?,
          done_ratio?,
          is_private?,
          estimated_hours?,
          status_id?,
          priority_id?,
          tracker_id?,
          assigned_to_id?,
          category_id?,
          parent_issue_id?,
          fixed_version_id?,
          start_date?,
          due_date?,
        ),
      )
    },
  )
  |> @schema.field("id", record_id())
  |> @schema.optional("subject", @schema.string())
  |> @schema.optional("description", @schema.string())
  |> @schema.optional(
    "status_id",
    record_id().describe(
      "Status to move the issue to. Redmine ignores, without an error, a status the workflow does not allow; `show` with `include: [\"allowedStatuses\"]` lists the ones it does.",
    ),
  )
  |> @schema.optional("priority_id", record_id())
  |> @schema.optional("tracker_id", record_id())
  |> @schema.optional(
    "assigned_to_id",
    clearable(record_id(), "User to assign the issue to; `null` unassigns it."),
  )
  |> @schema.optional(
    "category_id",
    clearable(
      record_id(),
      "Issue category to file the issue under; `null` removes the category.",
    ),
  )
  |> @schema.optional(
    "parent_issue_id",
    clearable(
      record_id(),
      "Issue to make the parent of this one; `null` detaches it from its parent.",
    ),
  )
  |> @schema.optional(
    "fixed_version_id",
    clearable(
      record_id(),
      "Version to move the issue into; `null` takes it out of its version.",
    ),
  )
  |> @schema.optional(
    "start_date",
    clearable(@schema.iso_date(), start_date_text(true)),
  )
  |> @schema.optional(
    "due_date",
    clearable(@schema.iso_date(), due_date_text(true)),
  )
  |> @schema.optional("done_ratio", @schema.integer())
  |> @schema.optional("is_private", @schema.boolean())
  |> @schema.optional("estimated_hours", @schema.number())
  |> @schema.optional("notes", @schema.string())
  |> @schema.optional("private_notes", @schema.boolean())
  |> @schema.Obj::done

///|
let delete_input : @schema.Schema[IssueAction] = @schema.object(id => IssueAction::Delete(id))
  |> @schema.field("id", record_id())
  |> @schema.Obj::done

///|
fn journal_id() -> @schema.Schema[Int32] {
  record_id().describe(
    "Id of the comment (journal), as listed by `show` with `include: [\"journals\"]`.",
  )
}

///|
/// "At least one of `notes` and `private_notes`" is two alternatives of one
/// action, because the advertised JSON Schema cannot state it as a check on a
/// single object. The second has no `notes` field, so a call whose `notes` is
/// not valid text is rejected instead of falling through and losing it.
let update_note_text_input : @schema.Schema[IssueAction] = @schema.object(journal_id => {
    notes => {
      private_notes => IssueAction::UpdateNote(journal_id, notes=Some(notes), private_notes~)
    }
  })
  |> @schema.field("journal_id", journal_id())
  |> @schema.field(
    "notes",
    @schema.string(min_length=1).describe(
      "New text of the comment. To erase it, use `delete_note`.",
    ),
  )
  |> @schema.optional("private_notes", @schema.boolean())
  |> @schema.Obj::done

///|
let update_note_visibility_input : @schema.Schema[IssueAction] = @schema.object(journal_id => {
      private_notes => {
        IssueAction::UpdateNote(journal_id, notes=None, private_notes=Some(private_notes))
      }
    },
  )
  |> @schema.field("journal_id", journal_id())
  |> @schema.field("private_notes", @schema.boolean())
  |> @schema.Obj::done

///|
let delete_note_input : @schema.Schema[IssueAction] = @schema.object(journal_id => {
    IssueAction::DeleteNote(journal_id)
  })
  |> @schema.field("journal_id", journal_id())
  |> @schema.Obj::done

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
