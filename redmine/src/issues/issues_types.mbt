///|
/// A custom field as it appears on an issue.
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct CustomField {
  id : Int32
  name : String
  value : @redmine.CustomFieldValue?
  multiple : Bool?
}

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
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct Status {
  id : Int32
  name : String
  is_closed : Bool?
}

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
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct Parent {
  id : Int32
}

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
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct Child {
  id : Int32
  tracker : @redmine.IdName
  subject : String
}

///|
pub extend Child with @json.FromJson::{from_json}

///|
pub extend Child with ToJson::{to_json}

///|
pub extend Child with Eq::{equal, not_equal}

///|
pub extend Child with @debug.Debug::{to_repr}

///|
/// A relation between issues, as listed by `include=relations`.
/// The relation type is the closed set `@relations.Type` spells, so a relation type added by a plugin fails to decode as it does in `@relations`.
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct Relation {
  id : Int32?
  issue_id : Int32?
  issue_to_id : Int32?
  relation_type : @relations.Type?
  delay : Int32?
}

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
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct JournalDetail {
  property : String
  name : String
  old_value : String?
  new_value : String?
}

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
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct Journal {
  id : Int32
  user : @redmine.IdName
  notes : String?
  created_on : String
  private_notes : Bool
  details : Array[JournalDetail]
}

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
#derive(FromJson, ToJson, Eq, Debug)
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
  attachments : Array[@attachments.Attachment]?
  relations : Array[Relation]?
  children : Array[Child]?
  changesets : Array[Json]?
  watchers : Array[@redmine.IdName]?
  allowed_statuses : Array[Status]?
}

///|
pub extend Issue with @json.FromJson::{from_json}

///|
pub extend Issue with ToJson::{to_json}

///|
pub extend Issue with Eq::{equal, not_equal}

///|
pub extend Issue with @debug.Debug::{to_repr}
