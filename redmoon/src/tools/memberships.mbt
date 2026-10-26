///|
priv enum MembershipAction {
  List(@redmine.ProjectRef, limit~ : Int32?)
}

///|
let membership_input : @schema.Schema[MembershipAction] = {
  let project_id = @schema.required("project_id", project_ref())
  @schema.keyed([
    (
      "list",
      @schema.record([project_id.as_member(), list_limit.as_member()], v => {
        List(v.get(project_id), limit=v.get(list_limit))
      }),
    ),
  ])
}

///|
/// `redmine_memberships`: the members of a project, which supply the ids `assigned_to_id` takes.
/// The only action reads, so the tool is the same in both modes.
pub fn memberships_tool(port : &MembershipPort) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_memberships",
    description="Lists the members of a Redmine project, each user or group with its roles, to find whom an issue can be assigned to.\nThe id to pass as `assigned_to_id` to `redmine_issues` is the principal's, `user.id` or `group.id`, never the membership's own top-level `id`.\nBeing listed does not make a principal assignable: one of its roles must have \"Issues can be assigned to this role\" enabled, a group also needs the Redmine setting \"Allow issue assignment to groups\", and the built-in groups `group_anonymous` and `group_non_member` cannot be assigned.\nPass the arguments under the single key `list`: `{\"list\": {\"project_id\": \"demo\"}}`.",
    input=membership_input,
    handler=async fn(action) {
      match action {
        List(project, limit~) =>
          respond(() => port.list_memberships(project, limit))
      }
    },
  )
}
