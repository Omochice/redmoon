///|
async test "live: a paged list honours limit" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let issues : Array[Json] = @paging.list_all(
    redmine,
    ["issues.json"],
    key="issues",
    query=[("status_id", "*")],
    limit=3,
  )
  assert_true(issues.length() <= 3)
}
