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
/// A token as `@attachments.upload` returns it, with the optional file details.
///
/// ```mbt check
/// test {
///   let token = @issues.UploadToken::new("7167.ed1ccdb093229ca1bd0b043618d88743")
///   assert_eq(token.filename, None)
///   let named = @issues.UploadToken::new(
///     "7168.0f3c",
///     filename="report.pdf",
///     content_type="application/pdf",
///   )
///   assert_eq(named.filename, Some("report.pdf"))
/// }
/// ```
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
pub(all) struct CustomFieldInput {
  id : Int32
  value : CustomFieldValue
} derive(Eq, Debug)

///|
pub extend CustomFieldInput with Eq::{equal, not_equal}

///|
pub extend CustomFieldInput with @debug.Debug::{to_repr}

///|
/// Fields of an issue to create; dates are `YYYY-MM-DD`.
pub struct Create {
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
  custom_fields : Array[CustomFieldInput]?
  uploads : Array[UploadToken]?
}

///|
/// The fields of an issue to create; only the required ones must be given.
///
/// ```mbt check
/// test {
///   let create = @issues.Create::new(
///     project_id=1,
///     tracker_id=1,
///     status_id=1,
///     priority_id=2,
///     subject="Login page returns 500",
///     due_date="2026-12-31",
///   )
///   assert_eq(create.subject, "Login page returns 500")
///   assert_eq(create.due_date, Some("2026-12-31"))
///   assert_true(create.description is None)
/// }
/// ```
pub fn Create::new(
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
  custom_fields? : Array[CustomFieldInput],
  uploads? : Array[UploadToken],
) -> Create {
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
pub struct Update {
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
  assigned_to_id : @redmine.Clearable[Int32]?
  category_id : @redmine.Clearable[Int32]?
  parent_issue_id : @redmine.Clearable[Int32]?
  fixed_version_id : @redmine.Clearable[Int32]?
  start_date : @redmine.Clearable[String]?
  due_date : @redmine.Clearable[String]?
  custom_fields : Array[CustomFieldInput]?
  uploads : Array[UploadToken]?
}

///|
/// The changes to apply to an issue; only the fields given are touched.
///
/// ```mbt check
/// test {
///   let update = @issues.Update::new(
///     notes="Moved to the next release",
///     assigned_to_id=Clear,
///     fixed_version_id=Set(5),
///   )
///   assert_eq(update.assigned_to_id, Some(@redmine.Clearable::Clear))
///   assert_eq(update.fixed_version_id, Some(@redmine.Clearable::Set(5)))
///   assert_true(update.subject is None)
/// }
/// ```
pub fn Update::new(
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
  assigned_to_id? : @redmine.Clearable[Int32],
  category_id? : @redmine.Clearable[Int32],
  parent_issue_id? : @redmine.Clearable[Int32],
  fixed_version_id? : @redmine.Clearable[Int32],
  start_date? : @redmine.Clearable[String],
  due_date? : @redmine.Clearable[String],
  custom_fields? : Array[CustomFieldInput],
  uploads? : Array[UploadToken],
) -> Update {
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
fn[T] @redmine.Clearable::to_member(
  clearable : @redmine.Clearable[T]?,
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
  @wire.present_members([
    ("token", Some(Json(self.token))),
    ("filename", self.filename.map(ToJson::to_json)),
    ("description", self.description.map(ToJson::to_json)),
    ("content_type", self.content_type.map(ToJson::to_json)),
  ])
}

///|
fn CustomFieldInput::to_json_object(self : CustomFieldInput) -> Json {
  Json::object({ "id": ToJson::to_json(self.id), "value": self.value.to_json() })
}

///|
fn custom_fields_member(fields : Array[CustomFieldInput]?) -> Json? {
  fields.map(fields => Json::array(fields.map(CustomFieldInput::to_json_object)))
}

///|
fn uploads_member(uploads : Array[UploadToken]?) -> Json? {
  uploads.map(uploads => Json::array(uploads.map(UploadToken::to_json_object)))
}

///|
fn Create::to_body(self : Create) -> Json {
  let issue = @wire.present_members([
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
fn Update::to_body(self : Update) -> Json {
  let issue = @wire.present_members([
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
      @redmine.Clearable::to_member(
        self.assigned_to_id,
        clear=Json(""),
        set=ToJson::to_json,
      ),
    ),
    (
      "category_id",
      @redmine.Clearable::to_member(self.category_id, set=ToJson::to_json),
    ),
    (
      "parent_issue_id",
      @redmine.Clearable::to_member(self.parent_issue_id, set=ToJson::to_json),
    ),
    (
      "fixed_version_id",
      @redmine.Clearable::to_member(self.fixed_version_id, set=ToJson::to_json),
    ),
    (
      "start_date",
      @redmine.Clearable::to_member(self.start_date, set=ToJson::to_json),
    ),
    (
      "due_date",
      @redmine.Clearable::to_member(self.due_date, set=ToJson::to_json),
    ),
    ("custom_fields", custom_fields_member(self.custom_fields)),
    ("uploads", uploads_member(self.uploads)),
  ])
  Json::object({ "issue": issue })
}
