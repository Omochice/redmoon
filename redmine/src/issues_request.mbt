///|
/// A file uploaded beforehand, to attach to an issue.
pub(all) struct UploadToken {
  token : String
  filename : String?
  description : String?
  content_type : String?
} derive(Eq, Debug)

///|
pub extend UploadToken with Eq::{equal, not_equal}

///|
pub extend UploadToken with @debug.Debug::{to_repr}

///|
pub fn UploadToken::new(
  token : String,
  filename? : String,
  description? : String,
  content_type? : String,
) -> UploadToken {
  { token, filename, description, content_type, }
}

///|
/// A custom field value to write.
pub(all) struct IssueCustomFieldInput {
  id : Int32
  value : IssueCustomFieldValue
} derive(Eq, Debug)

///|
pub extend IssueCustomFieldInput with Eq::{equal, not_equal}

///|
pub extend IssueCustomFieldInput with @debug.Debug::{to_repr}

///|
/// Fields of an issue to create; dates are `YYYY-MM-DD`.
pub struct IssueCreate {
  project_id : Int32
  tracker_id : Int32
  status_id : Int32
  priority_id : Int32
  subject : String
  description : String?
  category_id : Int32?
  fixed_version_id : Int32?
  assigned_to_id : Int32?
  parent_issue_id : Int32?
  watcher_user_ids : Array[Int32]?
  is_private : Bool?
  estimated_hours : Double?
  start_date : String?
  due_date : String?
  custom_fields : Array[IssueCustomFieldInput]?
  uploads : Array[UploadToken]?
}

///|
pub fn IssueCreate::new(
  project_id~ : Int32,
  tracker_id~ : Int32,
  status_id~ : Int32,
  priority_id~ : Int32,
  subject~ : String,
  description? : String,
  category_id? : Int32,
  fixed_version_id? : Int32,
  assigned_to_id? : Int32,
  parent_issue_id? : Int32,
  watcher_user_ids? : Array[Int32],
  is_private? : Bool,
  estimated_hours? : Double,
  start_date? : String,
  due_date? : String,
  custom_fields? : Array[IssueCustomFieldInput],
  uploads? : Array[UploadToken],
) -> IssueCreate {
  {
    project_id,
    tracker_id,
    status_id,
    priority_id,
    subject,
    description,
    category_id,
    fixed_version_id,
    assigned_to_id,
    parent_issue_id,
    watcher_user_ids,
    is_private,
    estimated_hours,
    start_date,
    due_date,
    custom_fields,
    uploads,
  }
}

///|
/// Changes to apply to an issue; an unset field is left as it is.
/// `Clear` empties the fields that can be emptied, dates are `YYYY-MM-DD`.
/// Redmine ignores, without an error, a status the workflow does not allow.
pub struct IssueUpdate {
  subject : String?
  description : String?
  notes : String?
  private_notes : Bool?
  done_ratio : Int32?
  is_private : Bool?
  estimated_hours : Double?
  status_id : Int32?
  priority_id : Int32?
  tracker_id : Int32?
  assigned_to_id : Clearable[Int32]?
  category_id : Clearable[Int32]?
  parent_issue_id : Clearable[Int32]?
  fixed_version_id : Clearable[Int32]?
  start_date : Clearable[String]?
  due_date : Clearable[String]?
  custom_fields : Array[IssueCustomFieldInput]?
  uploads : Array[UploadToken]?
}

///|
pub fn IssueUpdate::new(
  subject? : String,
  description? : String,
  notes? : String,
  private_notes? : Bool,
  done_ratio? : Int32,
  is_private? : Bool,
  estimated_hours? : Double,
  status_id? : Int32,
  priority_id? : Int32,
  tracker_id? : Int32,
  assigned_to_id? : Clearable[Int32],
  category_id? : Clearable[Int32],
  parent_issue_id? : Clearable[Int32],
  fixed_version_id? : Clearable[Int32],
  start_date? : Clearable[String],
  due_date? : Clearable[String],
  custom_fields? : Array[IssueCustomFieldInput],
  uploads? : Array[UploadToken],
) -> IssueUpdate {
  {
    subject,
    description,
    notes,
    private_notes,
    done_ratio,
    is_private,
    estimated_hours,
    status_id,
    priority_id,
    tracker_id,
    assigned_to_id,
    category_id,
    parent_issue_id,
    fixed_version_id,
    start_date,
    due_date,
    custom_fields,
    uploads,
  }
}

///|
fn[T] Clearable::to_member(
  clearable : Clearable[T]?,
  clear~ : Json = Json::null(),
  set~ : (T) -> Json,
) -> Json? {
  match clearable {
    None => None
    Some(Clear) => Some(clear)
    Some(Set(value)) => Some(set(value))
  }
}

///|
fn UploadToken::to_json_object(self : UploadToken) -> Json {
  present_members([
    ("token", Some(Json(self.token))),
    ("filename", self.filename.map(ToJson::to_json)),
    ("description", self.description.map(ToJson::to_json)),
    ("content_type", self.content_type.map(ToJson::to_json)),
  ])
}

///|
fn IssueCustomFieldInput::to_json_object(self : IssueCustomFieldInput) -> Json {
  Json::object({ "id": ToJson::to_json(self.id), "value": self.value.to_json() })
}

///|
fn custom_fields_member(fields : Array[IssueCustomFieldInput]?) -> Json? {
  fields.map(fields => {
    Json::array(fields.map(IssueCustomFieldInput::to_json_object))
  })
}

///|
fn uploads_member(uploads : Array[UploadToken]?) -> Json? {
  uploads.map(uploads => Json::array(uploads.map(UploadToken::to_json_object)))
}

///|
fn IssueCreate::to_body(self : IssueCreate) -> Json {
  let issue = present_members([
    ("project_id", Some(ToJson::to_json(self.project_id))),
    ("tracker_id", Some(ToJson::to_json(self.tracker_id))),
    ("status_id", Some(ToJson::to_json(self.status_id))),
    ("priority_id", Some(ToJson::to_json(self.priority_id))),
    ("subject", Some(Json(self.subject))),
    ("description", self.description.map(ToJson::to_json)),
    ("category_id", self.category_id.map(ToJson::to_json)),
    ("fixed_version_id", self.fixed_version_id.map(ToJson::to_json)),
    ("assigned_to_id", self.assigned_to_id.map(ToJson::to_json)),
    ("parent_issue_id", self.parent_issue_id.map(ToJson::to_json)),
    (
      "watcher_user_ids",
      self.watcher_user_ids.map(fn(ids) {
        Json::array(ids.map(ToJson::to_json))
      }),
    ),
    ("is_private", self.is_private.map(ToJson::to_json)),
    ("estimated_hours", self.estimated_hours.map(ToJson::to_json)),
    ("start_date", self.start_date.map(ToJson::to_json)),
    ("due_date", self.due_date.map(ToJson::to_json)),
    ("custom_fields", custom_fields_member(self.custom_fields)),
    ("uploads", uploads_member(self.uploads)),
  ])
  Json::object({ "issue": issue })
}

///|
fn IssueUpdate::to_body(self : IssueUpdate) -> Json {
  let issue = present_members([
    ("subject", self.subject.map(ToJson::to_json)),
    ("description", self.description.map(ToJson::to_json)),
    ("notes", self.notes.map(ToJson::to_json)),
    ("private_notes", self.private_notes.map(ToJson::to_json)),
    ("done_ratio", self.done_ratio.map(ToJson::to_json)),
    ("is_private", self.is_private.map(ToJson::to_json)),
    ("estimated_hours", self.estimated_hours.map(ToJson::to_json)),
    ("status_id", self.status_id.map(ToJson::to_json)),
    ("priority_id", self.priority_id.map(ToJson::to_json)),
    ("tracker_id", self.tracker_id.map(ToJson::to_json)),
    // Redmine ignores `assigned_to_id: null` and unassigns only on a blank string.
    (
      "assigned_to_id",
      Clearable::to_member(
        self.assigned_to_id,
        clear=Json(""),
        set=ToJson::to_json,
      ),
    ),
    ("category_id", Clearable::to_member(self.category_id, set=ToJson::to_json)),
    (
      "parent_issue_id",
      Clearable::to_member(self.parent_issue_id, set=ToJson::to_json),
    ),
    (
      "fixed_version_id",
      Clearable::to_member(self.fixed_version_id, set=ToJson::to_json),
    ),
    ("start_date", Clearable::to_member(self.start_date, set=ToJson::to_json)),
    ("due_date", Clearable::to_member(self.due_date, set=ToJson::to_json)),
    ("custom_fields", custom_fields_member(self.custom_fields)),
    ("uploads", uploads_member(self.uploads)),
  ])
  Json::object({ "issue": issue })
}
