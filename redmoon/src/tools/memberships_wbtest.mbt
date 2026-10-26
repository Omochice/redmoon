///|
struct FakeMemberships {
  mut listed : (@redmine.ProjectRef, Int32?)?
  failure : @redmine.RedmineError?
}

///|
fn FakeMemberships::new(failure? : @redmine.RedmineError) -> FakeMemberships {
  { listed: None, failure, }
}

///|
impl MembershipPort for FakeMemberships with fn list_memberships(
  self,
  project,
  limit,
) {
  self.listed = Some((project, limit))
  if self.failure is Some(error) {
    raise error
  }
  [
    {
      id: 7,
      project: { id: 1, name: "Demo", },
      principal: Group({ id: 12, name: "Support", }),
      roles: [{ id: 4, name: "Developer", inherited: false, }],
    },
    {
      id: 8,
      project: { id: 1, name: "Demo", },
      principal: User({ id: 5, name: "Jane Doe", }),
      roles: [{ id: 4, name: "Developer", inherited: true, }],
    },
  ]
}

///|
async test "list sends the project and limit to the port and answers the memberships" {
  let fake = FakeMemberships::new()
  let called = call_tool([memberships_tool(fake)], "redmine_memberships", {
    "list": { "project_id": "demo", "limit": 5 },
  })
  assert_eq(called.is_error, false)
  assert_eq(fake.listed, Some((Identifier("demo"), Some(5))))
  inspect(
    called.text,
    content=(
      #|[{"id":7,"project":{"id":1,"name":"Demo"},"group":{"id":12,"name":"Support"},"roles":[{"id":4,"name":"Developer","inherited":false}]},{"id":8,"project":{"id":1,"name":"Demo"},"user":{"id":5,"name":"Jane Doe"},"roles":[{"id":4,"name":"Developer","inherited":true}]}]
    ),
  )
}

///|
async test "list takes a numeric project id and no limit" {
  let fake = FakeMemberships::new()
  ignore(
    call_tool([memberships_tool(fake)], "redmine_memberships", {
      "list": { "project_id": 1 },
    }),
  )
  assert_eq(fake.listed, Some((Id(1), None)))
}

///|
async test "list without a project is rejected before reaching the port" {
  let fake = FakeMemberships::new()
  let called = call_tool([memberships_tool(fake)], "redmine_memberships", {
    "list": {},
  })
  assert_eq(called.is_error, true)
  assert_eq(fake.listed, None)
}

///|
async test "a Redmine failure of memberships becomes a failure payload" {
  let fake = FakeMemberships::new(
    failure=Response(status=403, errors=["Forbidden"]),
  )
  let called = call_tool([memberships_tool(fake)], "redmine_memberships", {
    "list": { "project_id": "demo" },
  })
  assert_eq(called.is_error, true)
  assert_eq(called.text, "{\"status\":403,\"errors\":[\"Forbidden\"]}")
}

///|
async test "tools/list advertises the memberships tool" {
  let advertised = list_tools([memberships_tool(FakeMemberships::new())]).stringify()
  inspect(
    advertised,
    content=(
      #|{"tools":[{"name":"redmine_memberships","description":"Lists the members of a Redmine project, each user or group with its roles, to find whom an issue can be assigned to.\nThe id to pass as `assigned_to_id` to `redmine_issues` is the principal's, `user.id` or `group.id`, never the membership's own top-level `id`.\nBeing listed does not make a principal assignable: one of its roles must have \"Issues can be assigned to this role\" enabled, a group also needs the Redmine setting \"Allow issue assignment to groups\", and the built-in groups `group_anonymous` and `group_non_member` cannot be assigned.\nPass the arguments under the single key `list`: `{\"list\": {\"project_id\": \"demo\"}}`.","inputSchema":{"type":"object","properties":{"list":{"type":"object","properties":{"project_id":{"anyOf":[{"type":"integer","minimum":1},{"type":"string","pattern":"^\\S+$"}],"description":"Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...)."},"limit":{"type":"integer","minimum":1}},"required":["project_id"],"additionalProperties":false}},"minProperties":1,"maxProperties":1,"additionalProperties":false}}]}
    ),
  )
}
