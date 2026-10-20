///|
async test "the saved queries include a global query and the seeded demo query with its project" {
  let redmine = @livetest.redmine()
  let queries = redmine |> @queries.list()
  assert_true(queries.any(fn(q) { q.project_id is None }))
  guard queries.iter().find_first(q => q.name == "Demo open issues")
    is Some(seeded) else {
    fail("the seeded query is missing; run `task redmine:seed`")
  }
  assert_eq(seeded.project_id, Some(1))
  assert_true(seeded.is_public)
}
