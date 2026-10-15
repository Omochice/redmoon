///|
/// The value of an issue custom field: one string, or several for a multi-value field.
pub(all) enum IssueCustomFieldValue {
  Single(String)
  Multiple(Array[String])
} derive(Eq, Debug)

///|
pub extend IssueCustomFieldValue with Eq::{equal, not_equal}

///|
pub extend IssueCustomFieldValue with @debug.Debug::{to_repr}

///|
pub extend IssueCustomFieldValue with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for IssueCustomFieldValue with fn from_json(json, path) {
  match json {
    String(value) => Single(value)
    Array(_) => Multiple(@json.from_json(json, path~))
    _ =>
      raise @json.JsonDecodeError(
        (path, "IssueCustomFieldValue::from_json: expected string or array"),
      )
  }
}

///|
pub extend IssueCustomFieldValue with ToJson::{to_json}

///|
pub impl ToJson for IssueCustomFieldValue with fn to_json(self) {
  match self {
    Single(value) => Json(value)
    Multiple(values) => Json(values)
  }
}

///|
/// A custom field as it appears on an issue.
pub(all) struct IssueCustomField {
  id : Int32
  name : String
  value : IssueCustomFieldValue?
  multiple : Bool?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend IssueCustomField with @json.FromJson::{from_json}

///|
pub extend IssueCustomField with ToJson::{to_json}

///|
pub extend IssueCustomField with Eq::{equal, not_equal}

///|
pub extend IssueCustomField with @debug.Debug::{to_repr}

///|
/// An issue status; `is_closed` is absent where Redmine does not report it.
pub(all) struct IssueStatus {
  id : Int32
  name : String
  is_closed : Bool?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend IssueStatus with @json.FromJson::{from_json}

///|
pub extend IssueStatus with ToJson::{to_json}

///|
pub extend IssueStatus with Eq::{equal, not_equal}

///|
pub extend IssueStatus with @debug.Debug::{to_repr}

///|
/// The parent of an issue.
pub(all) struct IssueParent {
  id : Int32
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend IssueParent with @json.FromJson::{from_json}

///|
pub extend IssueParent with ToJson::{to_json}

///|
pub extend IssueParent with Eq::{equal, not_equal}

///|
pub extend IssueParent with @debug.Debug::{to_repr}

///|
/// A child issue, as listed by `include=children`.
pub(all) struct IssueChild {
  id : Int32
  tracker : IdName
  subject : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend IssueChild with @json.FromJson::{from_json}

///|
pub extend IssueChild with ToJson::{to_json}

///|
pub extend IssueChild with Eq::{equal, not_equal}

///|
pub extend IssueChild with @debug.Debug::{to_repr}

///|
/// A file attached to an issue.
pub(all) struct IssueAttachment {
  id : Int32
  filename : String
  filesize : Int32
  content_type : String?
  description : String?
  content_url : String
  thumbnail_url : String?
  author : IdName
  created_on : String
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend IssueAttachment with @json.FromJson::{from_json}

///|
pub extend IssueAttachment with ToJson::{to_json}

///|
pub extend IssueAttachment with Eq::{equal, not_equal}

///|
pub extend IssueAttachment with @debug.Debug::{to_repr}

///|
/// A relation between issues, as listed by `include=relations`.
pub(all) struct IssueRelation {
  id : Int32?
  issue_id : Int32?
  issue_to_id : Int32?
  relation_type : String?
  delay : Int32?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend IssueRelation with @json.FromJson::{from_json}

///|
pub extend IssueRelation with ToJson::{to_json}

///|
pub extend IssueRelation with Eq::{equal, not_equal}

///|
pub extend IssueRelation with @debug.Debug::{to_repr}

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
  user : IdName
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
  project : IdName
  tracker : IdName
  status : IssueStatus
  priority : IdName
  author : IdName
  assigned_to : IdName?
  category : IdName?
  fixed_version : IdName?
  parent : IssueParent?
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
  custom_fields : Array[IssueCustomField]?
  journals : Array[Journal]?
  attachments : Array[IssueAttachment]?
  relations : Array[IssueRelation]?
  children : Array[IssueChild]?
  changesets : Array[Json]?
  watchers : Array[IdName]?
  allowed_statuses : Array[IssueStatus]?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Issue with @json.FromJson::{from_json}

///|
pub extend Issue with ToJson::{to_json}

///|
pub extend Issue with Eq::{equal, not_equal}

///|
pub extend Issue with @debug.Debug::{to_repr}
