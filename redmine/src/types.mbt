///|
/// A reference to another Redmine record by id and display name.
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct IdName {
  id : Int32
  name : String
}

///|
pub extend IdName with @json.FromJson::{from_json}

///|
pub extend IdName with ToJson::{to_json}

///|
pub extend IdName with Eq::{equal, not_equal}

///|
pub extend IdName with @debug.Debug::{to_repr}
