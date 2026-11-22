///|
async test "a limit caps a list" {
  let redmine = @livetest.redmine()
  let limit = 3
  let probes = []
  defer (for probe in probes {
    @livetest.delete_probe_issue(redmine, probe)
  })
  // One probe more than the limit, so the cap is what stops the list whatever else the instance holds.
  for i = 0; i <= limit; i = i + 1 {
    probes.push(@livetest.create_probe_issue(redmine, "redmoon-limit-\{i}"))
  }
  let issues = redmine
    |> @issues.list(@issues.ListQuery::new(status_id=All), limit~)
  assert_eq(issues.length(), limit)
}
