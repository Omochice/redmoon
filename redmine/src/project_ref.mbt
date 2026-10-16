///|
/// A project as Redmine's `/projects/:project_id/...` routes accept it: the
/// numeric id or the string identifier that appears in project URLs.
pub(all) enum ProjectRef {
  Id(Int32)
  Identifier(String)
} derive(Eq, Debug)

///|
pub extend ProjectRef with Eq::{equal, not_equal}

///|
pub extend ProjectRef with @debug.Debug::{to_repr}

///|
/// The path segment that names the project in a request path.
pub fn ProjectRef::segment(self : ProjectRef) -> String {
  match self {
    Id(id) => id.to_string()
    Identifier(identifier) => identifier
  }
}
