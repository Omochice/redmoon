///|
/// The value of an issue custom field: one string, or several for a multi-value field.
pub(all) enum CustomFieldValue {
  Single(String)
  Multiple(Array[String])
} derive(Eq, Debug)

///|
pub extend CustomFieldValue with Eq::{equal, not_equal}

///|
pub extend CustomFieldValue with @debug.Debug::{to_repr}

///|
pub extend CustomFieldValue with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for CustomFieldValue with fn from_json(json, path) {
  match json {
    String(value) => Single(value)
    Array(_) => Multiple(@json.from_json(json, path~))
    _ =>
      raise @json.JsonDecodeError(
        (path, "CustomFieldValue::from_json: expected string or array"),
      )
  }
}

///|
pub extend CustomFieldValue with ToJson::{to_json}

///|
pub impl ToJson for CustomFieldValue with fn to_json(self) {
  match self {
    Single(value) => Json(value)
    Multiple(values) => Json(values)
  }
}

///|
/// A custom field as it appears on an issue.
pub(all) struct CustomField {
  id : Int32
  name : String
  value : CustomFieldValue?
  multiple : Bool?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend CustomField with @json.FromJson::{from_json}

///|
pub extend CustomField with ToJson::{to_json}

///|
pub extend CustomField with Eq::{equal, not_equal}

///|
pub extend CustomField with @debug.Debug::{to_repr}

///|
/// An issue status; `is_closed` is absent where Redmine does not report it.
pub(all) struct Status {
  id : Int32
  name : String
  is_closed : Bool?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Status with @json.FromJson::{from_json}

///|
pub extend Status with ToJson::{to_json}

///|
pub extend Status with Eq::{equal, not_equal}

///|
pub extend Status with @debug.Debug::{to_repr}

///|
/// The parent of an issue.
pub(all) struct Parent {
  id : Int32
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Parent with @json.FromJson::{from_json}

///|
pub extend Parent with ToJson::{to_json}

///|
pub extend Parent with Eq::{equal, not_equal}

///|
pub extend Parent with @debug.Debug::{to_repr}

///|
/// A child issue, as listed by `include=children`.
pub(all) struct Child {
  id : Int32
  tracker : @redmine.IdName
  subject : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Child with @json.FromJson::{from_json}

///|
pub extend Child with ToJson::{to_json}

///|
pub extend Child with Eq::{equal, not_equal}

///|
pub extend Child with @debug.Debug::{to_repr}

///|
/// A file attached to an issue.
pub(all) struct Attachment {
  id : Int32
  filename : String
  filesize : Int32
  content_type : String?
  description : String?
  content_url : String
  thumbnail_url : String?
  author : @redmine.IdName
  created_on : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Attachment with @json.FromJson::{from_json}

///|
pub extend Attachment with ToJson::{to_json}

///|
pub extend Attachment with Eq::{equal, not_equal}

///|
pub extend Attachment with @debug.Debug::{to_repr}

///|
/// A relation between issues, as listed by `include=relations`.
pub(all) struct Relation {
  id : Int32?
  issue_id : Int32?
  issue_to_id : Int32?
  relation_type : String?
  delay : Int32?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Relation with @json.FromJson::{from_json}

///|
pub extend Relation with ToJson::{to_json}

///|
pub extend Relation with Eq::{equal, not_equal}

///|
pub extend Relation with @debug.Debug::{to_repr}

///|
/// One field change recorded in a journal.
pub(all) struct JournalDetail {
  property : String
  name : String
  old_value : String?
  new_value : String?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend JournalDetail with @json.FromJson::{from_json}

///|
pub extend JournalDetail with ToJson::{to_json}

///|
pub extend JournalDetail with Eq::{equal, not_equal}

///|
pub extend JournalDetail with @debug.Debug::{to_repr}

///|
/// A comment and field-change history entry of an issue.
pub(all) struct Journal {
  id : Int32
  user : @redmine.IdName
  notes : String?
  created_on : String
  private_notes : Bool
  details : Array[JournalDetail]
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Journal with @json.FromJson::{from_json}

///|
pub extend Journal with ToJson::{to_json}

///|
pub extend Journal with Eq::{equal, not_equal}

///|
pub extend Journal with @debug.Debug::{to_repr}

///|
/// An issue.
/// The association fields (`journals` and below) are present only when they
/// were asked for with the matching include.
pub(all) struct Issue {
  id : Int32
  project : @redmine.IdName
  tracker : @redmine.IdName
  status : Status
  priority : @redmine.IdName
  author : @redmine.IdName
  assigned_to : @redmine.IdName?
  category : @redmine.IdName?
  fixed_version : @redmine.IdName?
  parent : Parent?
  subject : String
  description : String?
  start_date : String?
  due_date : String?
  done_ratio : Int32
  is_private : Bool
  estimated_hours : Double?
  total_estimated_hours : Double?
  spent_hours : Double?
  total_spent_hours : Double?
  created_on : String
  updated_on : String
  closed_on : String?
  custom_fields : Array[CustomField]?
  journals : Array[Journal]?
  attachments : Array[Attachment]?
  relations : Array[Relation]?
  children : Array[Child]?
  changesets : Array[Json]?
  watchers : Array[@redmine.IdName]?
  allowed_statuses : Array[Status]?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Issue with @json.FromJson::{from_json}

///|
pub extend Issue with ToJson::{to_json}

///|
pub extend Issue with Eq::{equal, not_equal}

///|
pub extend Issue with @debug.Debug::{to_repr}
