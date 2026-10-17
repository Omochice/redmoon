///|
/// A project as Redmine's `/projects/:project_id/...` routes accept it: the
/// numeric id or the string identifier that appears in project URLs.
///
/// ```mbt check
/// test {
///   let by_id : @redmine.ProjectRef = Id(1)
///   let by_identifier : @redmine.ProjectRef = Identifier("demo")
///   inspect(by_id.segment(), content="1")
///   inspect(by_identifier.segment(), content="demo")
/// }
/// ```
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
///
/// ```mbt check
/// test {
///   inspect(@redmine.ProjectRef::Id(42).segment(), content="42")
///   inspect(@redmine.ProjectRef::Identifier("demo").segment(), content="demo")
/// }
/// ```
pub fn ProjectRef::segment(self : ProjectRef) -> String {
  match self {
    Id(id) => id.to_string()
    Identifier(identifier) => identifier
  }
}
