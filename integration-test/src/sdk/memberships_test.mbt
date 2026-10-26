///|
async test "demo memberships carry the seeded group and the role its user inherits" {
  let redmine = @livetest.redmine()
  for
    project in [
      @redmine.ProjectRef::Identifier("demo"),
      @redmine.ProjectRef::Id(1),
    ] {
    let memberships = redmine |> @memberships.list(project)
    guard memberships.search_by(m => {
        m.principal is Group({ name: "Redmoon team", .. })
      })
      is Some(group_index) else {
      fail("no membership of the seeded group")
    }
    assert_true(
      memberships[group_index].roles.any(r => {
        r.name == "Developer" && !r.inherited
      }),
    )
    guard memberships.search_by(m => {
        m.principal is User({ name: "Redmoon Member", .. })
      })
      is Some(user_index) else {
      fail("no membership of the seeded group's user")
    }
    assert_true(
      memberships[user_index].roles.any(r => {
        r.name == "Developer" && r.inherited
      }),
    )
  }
}

///|
async test "a memberships limit caps the count" {
  let redmine = @livetest.redmine()
  let memberships = redmine |> @memberships.list(Identifier("demo"), limit=1)
  assert_eq(memberships.length(), 1)
}

///|
async test "memberships of a missing project raise Response 404" {
  let redmine = @livetest.redmine()
  try
    redmine |> @memberships.list(Identifier("redmoon-no-such-project"))
  catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
