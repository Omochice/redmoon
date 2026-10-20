///|
/// An association a listed issue can carry.
pub(all) enum ListInclude {
  Attachments
  Relations
} derive(Eq, Debug)

///|
pub extend ListInclude with Eq::{equal, not_equal}

///|
pub extend ListInclude with @debug.Debug::{to_repr}

///|
/// An association a shown issue can carry.
pub(all) enum Include {
  Children
  Attachments
  Relations
  Changesets
  Journals
  Watchers
  AllowedStatuses
} derive(Eq, Debug)

///|
pub extend Include with Eq::{equal, not_equal}

///|
pub extend Include with @debug.Debug::{to_repr}

///|
/// Which issues to list by status.
///
/// ```mbt check
/// test {
///   let open_in_project = @issues.ListQuery::new(project_id=1, status_id=Open)
///   let one_status = @issues.ListQuery::new(status_id=Id(3))
///   assert_eq(open_in_project.status_id, Some(@issues.StatusFilter::Open))
///   assert_eq(one_status.status_id, Some(@issues.StatusFilter::Id(3)))
/// }
/// ```
pub(all) enum StatusFilter {
  Id(Int32)
  Open
  Closed
  All
} derive(Eq, Debug)

///|
pub extend StatusFilter with Eq::{equal, not_equal}

///|
pub extend StatusFilter with @debug.Debug::{to_repr}

///|
/// Which issues to list by assignee.
pub(all) enum AssigneeFilter {
  User(Int32)
  /// The user the API key belongs to.
  Me
} derive(Eq, Debug)

///|
pub extend AssigneeFilter with Eq::{equal, not_equal}

///|
pub extend AssigneeFilter with @debug.Debug::{to_repr}

///|
/// Conditions for `Redmine::list_issues`; an unset condition does not filter.
pub struct ListQuery {
  includes : Array[ListInclude]
  project_id : Int32?
  tracker_id : Int32?
  status_id : StatusFilter?
  fixed_version_id : Int32?
  assigned_to_id : AssigneeFilter?
  start_date : DateFilter?
  due_date : DateFilter?
  created_on : PastDateFilter?
  updated_on : PastDateFilter?
  closed_on : PastDateFilter?
}

///|
/// Conditions for `list`; an unset condition does not filter.
///
/// ```mbt check
/// test {
///   let query = @issues.ListQuery::new(project_id=1, status_id=Open, includes=[
///     Attachments,
///   ])
///   assert_eq(query.project_id, Some(1))
///   assert_eq(query.status_id, Some(@issues.StatusFilter::Open))
///   assert_eq(query.includes, [@issues.ListInclude::Attachments])
///   assert_true(query.tracker_id is None)
/// }
/// ```
pub fn ListQuery::new(
  includes~ : Array[ListInclude] = [],
  project_id? : Int32,
  tracker_id? : Int32,
  status_id? : StatusFilter,
  fixed_version_id? : Int32,
  assigned_to_id? : AssigneeFilter,
  start_date? : DateFilter,
  due_date? : DateFilter,
  created_on? : PastDateFilter,
  updated_on? : PastDateFilter,
  closed_on? : PastDateFilter,
) -> ListQuery {
  {
    includes,
    project_id,
    tracker_id,
    status_id,
    fixed_version_id,
    assigned_to_id,
    start_date,
    due_date,
    created_on,
    updated_on,
    closed_on,
  }
}

///|
fn ListInclude::name(self : ListInclude) -> String {
  match self {
    Attachments => "attachments"
    Relations => "relations"
  }
}

///|
fn Include::name(self : Include) -> String {
  match self {
    Children => "children"
    Attachments => "attachments"
    Relations => "relations"
    Changesets => "changesets"
    Journals => "journals"
    Watchers => "watchers"
    AllowedStatuses => "allowed_statuses"
  }
}

///|
fn StatusFilter::query_value(self : StatusFilter) -> String {
  match self {
    Id(id) => id.to_string()
    Open => "open"
    Closed => "closed"
    All => "*"
  }
}

///|
fn AssigneeFilter::query_value(self : AssigneeFilter) -> String {
  match self {
    User(id) => id.to_string()
    Me => "me"
  }
}

///|
/// Joins includes names as Redmine expects, dropping repeats.
fn include_value(names : Array[String]) -> String {
  let unique = []
  for name in names {
    if !unique.contains(name) {
      unique.push(name)
    }
  }
  unique.join(",")
}

///|
/// Which issues `list` returns, encoded as the query of `GET /issues.json`.
/// Only this package implements it, so a selection cannot carry a parameter Redmine does not read.
pub trait Selection {
  fn to_query(Self) -> Array[(String, String)]
}

///|
pub extend ListQuery with Selection::{to_query}

///|
pub impl Selection for ListQuery with fn to_query(self) {
  let pairs = []
  if !self.includes.is_empty() {
    pairs.push(("include", include_value(self.includes.map(ListInclude::name))))
  }
  if self.project_id is Some(id) {
    pairs.push(("project_id", id.to_string()))
  }
  if self.tracker_id is Some(id) {
    pairs.push(("tracker_id", id.to_string()))
  }
  if self.status_id is Some(status) {
    pairs.push(("status_id", status.query_value()))
  }
  if self.fixed_version_id is Some(id) {
    pairs.push(("fixed_version_id", id.to_string()))
  }
  if self.assigned_to_id is Some(assignee) {
    pairs.push(("assigned_to_id", assignee.query_value()))
  }
  if self.start_date is Some(filter) {
    pairs.push(("start_date", filter.query_value()))
  }
  if self.due_date is Some(filter) {
    pairs.push(("due_date", filter.query_value()))
  }
  if self.created_on is Some(filter) {
    pairs.push(("created_on", filter.query_value()))
  }
  if self.updated_on is Some(filter) {
    pairs.push(("updated_on", filter.query_value()))
  }
  if self.closed_on is Some(filter) {
    pairs.push(("closed_on", filter.query_value()))
  }
  pairs
}

///|
/// A query saved in Redmine, which supplies its own filters, so none can be added here.
pub struct SavedQuery {
  query_id : Int32
  project_id : Int32?
  includes : Array[ListInclude]
}

///|
/// Selects the issues of saved query `query_id`.
/// A project query answers only under `project_id` of its own project, and a global query is narrowed to `project_id` when it is given.
///
/// ```mbt check
/// test {
///   let query = @issues.SavedQuery::new(3, project_id=1, includes=[Relations])
///   assert_eq(query.query_id, 3)
///   assert_eq(query.project_id, Some(1))
///   assert_eq(query.includes, [@issues.ListInclude::Relations])
/// }
/// ```
pub fn SavedQuery::new(
  query_id : Int32,
  project_id? : Int32,
  includes~ : Array[ListInclude] = [],
) -> SavedQuery {
  { query_id, project_id, includes, }
}

///|
pub extend SavedQuery with Selection::{to_query}

///|
pub impl Selection for SavedQuery with fn to_query(self) {
  let pairs = [("query_id", self.query_id.to_string())]
  if self.project_id is Some(id) {
    pairs.push(("project_id", id.to_string()))
  }
  if !self.includes.is_empty() {
    pairs.push(("include", include_value(self.includes.map(ListInclude::name))))
  }
  pairs
}
