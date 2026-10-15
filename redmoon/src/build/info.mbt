///|
/// The commit the binary was built from; CI overwrites this file before a
/// release build, so a build from source reports `None`.
pub let commit : String? = None

///|
/// Whether the tree had uncommitted changes at build time.
pub let dirty : Bool? = None
