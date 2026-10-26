///|
/// The Redmine operation behind `redmine_memberships`.
pub(open) trait MembershipPort {
  async fn list_memberships(Self, @redmine.ProjectRef, Int32?) -> Array[
    @memberships.Membership,
  ] raise @redmine.RedmineError
}

///|
pub impl MembershipPort for @redmine.Redmine with fn list_memberships(
  self,
  project,
  limit,
) {
  self |> @memberships.list(project, limit?)
}
