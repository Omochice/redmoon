///|
/// The commit a binary was built from.
pub(all) struct BuildInfo {
  commit : String
  dirty : Bool
} derive(ToJson)

///|
pub extend BuildInfo with ToJson::{to_json}

///|
/// The build info embedded in this binary; CI overwrites this file before a
/// release build, so a build from source reports `None`.
pub let build : BuildInfo? = None
