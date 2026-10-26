///|
fn decode_membership(text : String) -> Membership raise {
  @json.from_json(@json.parse(text))
}

///|
test "a user membership decodes with the user as its principal" {
  let membership = decode_membership(
    (
      #|{"id":7,"project":{"id":1,"name":"Demo"},"user":{"id":5,"name":"Jane Doe"},"roles":[{"id":4,"name":"Developer"}]}
    ),
  )
  assert_eq(membership.id, 7)
  assert_eq(membership.project, { id: 1, name: "Demo", })
  assert_eq(membership.principal, User({ id: 5, name: "Jane Doe", }))
  assert_eq(membership.roles, [{ id: 4, name: "Developer", inherited: false, }])
}

///|
test "a group membership decodes with the group as its principal" {
  let membership = decode_membership(
    (
      #|{"id":8,"project":{"id":1,"name":"Demo"},"group":{"id":12,"name":"Support"},"roles":[{"id":3,"name":"Manager"},{"id":4,"name":"Developer"}]}
    ),
  )
  assert_eq(membership.principal, Group({ id: 12, name: "Support", }))
  assert_eq(membership.roles.length(), 2)
}

///|
test "a role inherited from a group is marked as inherited" {
  let membership = decode_membership(
    (
      #|{"id":9,"project":{"id":1,"name":"Demo"},"user":{"id":5,"name":"Jane Doe"},"roles":[{"id":4,"name":"Developer","inherited":true},{"id":5,"name":"Reporter"}]}
    ),
  )
  assert_eq(membership.roles, [
    { id: 4, name: "Developer", inherited: true, },
    { id: 5, name: "Reporter", inherited: false, },
  ])
}

///|
test "the built-in groups decode as their own principals" {
  let anonymous = decode_membership(
    (
      #|{"id":10,"project":{"id":1,"name":"Demo"},"group_anonymous":{"id":2,"name":"Anonymous users"},"roles":[{"id":5,"name":"Reporter"}]}
    ),
  )
  assert_eq(
    anonymous.principal,
    AnonymousGroup({ id: 2, name: "Anonymous users", }),
  )
  let non_member = decode_membership(
    (
      #|{"id":11,"project":{"id":1,"name":"Demo"},"group_non_member":{"id":3,"name":"Non member users"},"roles":[{"id":5,"name":"Reporter"}]}
    ),
  )
  assert_eq(
    non_member.principal,
    NonMemberGroup({ id: 3, name: "Non member users", }),
  )
}

///|
test "a membership without a known principal fails to decode" {
  try
    decode_membership(
      (
        #|{"id":12,"project":{"id":1,"name":"Demo"},"roles":[]}
      ),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected a decode error")
  }
}

///|
test "a membership encodes its principal under Redmine's key" {
  let membership : Membership = {
    id: 9,
    project: { id: 1, name: "Demo", },
    principal: Group({ id: 12, name: "Support", }),
    roles: [{ id: 4, name: "Developer", inherited: true, }],
  }
  inspect(
    membership.to_json().stringify(),
    content=(
      #|{"id":9,"project":{"id":1,"name":"Demo"},"group":{"id":12,"name":"Support"},"roles":[{"id":4,"name":"Developer","inherited":true}]}
    ),
  )
  let anonymous : Membership = {
    ..membership,
    principal: AnonymousGroup({ id: 2, name: "Anonymous users", }),
    roles: [{ id: 5, name: "Reporter", inherited: false, }],
  }
  inspect(
    anonymous.to_json().stringify(),
    content=(
      #|{"id":9,"project":{"id":1,"name":"Demo"},"group_anonymous":{"id":2,"name":"Anonymous users"},"roles":[{"id":5,"name":"Reporter","inherited":false}]}
    ),
  )
}
