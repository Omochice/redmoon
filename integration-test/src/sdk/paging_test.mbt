///|
async test "Redmine honours limit across the pages of a list" {
  let redmine = @livetest.redmine()
  let issues = redmine
    |> @issues.list(@issues.ListQuery::new(status_id=All), limit=3)
  assert_true(issues.length() <= 3)
}
