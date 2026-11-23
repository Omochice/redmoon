///|
async test "a time entry is created, listed, shown, updated, and deleted" {
  let redmine = @livetest.redmine()
  @livetest.ensure_time_tracking(redmine)
  let activities = redmine |> @enumerations.time_entry_activities()
  assert_false(activities.is_empty())
  let activity_id = activities[0].id
  let spent_on = "2031-06-15"
  let created = redmine
    |> @time_entries.create(
      @time_entries.Create::new(
        hours=1.5,
        project_id=1,
        spent_on~,
        activity_id~,
        comments="time entries integration test",
      ),
    )
  defer @livetest.cleanup(() => redmine |> @time_entries.delete(created.id))
  assert_eq(created.hours, 1.5)
  assert_eq(created.project.id, 1)
  assert_eq(created.activity.id, activity_id)
  assert_eq(created.spent_on, spent_on)
  let listed = redmine
    |> @time_entries.list(
      @time_entries.ListQuery::new(project_id=1, from=spent_on, to=spent_on),
    )
  assert_true(listed.any(fn(entry) { entry.id == created.id }))
  assert_eq(redmine |> @time_entries.show(created.id), created)
  redmine
  |> @time_entries.update(created.id, @time_entries.Update::new(hours=2.0))
  let updated = redmine |> @time_entries.show(created.id)
  assert_eq(updated.hours, 2.0)
  assert_eq(updated.comments, Some("time entries integration test"))
  redmine |> @time_entries.delete(created.id)
  try redmine |> @time_entries.show(created.id) catch {
    @redmine.Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
