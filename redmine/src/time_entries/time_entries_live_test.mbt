///|
/// Only the modules are read, because they are the only part of the project this test changes.
priv struct TimeEntriesProject {
  enabled_modules : Array[@redmine.IdName]
} derive(FromJson)

///|
/// Turns on the time tracking module of project 1 when it is off, since Redmine refuses time entries for a project without it.
async fn ensure_time_tracking(
  redmine : @redmine.Redmine,
) -> Unit raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Get, ["projects", "1.json"], query=[
      ("include", "enabled_modules"),
    ])
  let project : TimeEntriesProject = @decode.decode_field(json, "project")
  let names = project.enabled_modules.map(fn(enabled) { enabled.name })
  if names.contains("time_tracking") {
    return
  }
  let body_names = names.map(fn(name) { Json::string(name) })
  body_names.push(Json::string("time_tracking"))
  let _ = @redmine.send(
    redmine,
    Put,
    ["projects", "1.json"],
    body=Json::object({
      "project": Json::object({
        "enabled_module_names": Json::array(body_names),
      }),
    }),
  )
}

///|
async test "live: a time entry is created, listed, shown, updated, and deleted" {
  guard @livetest.redmine() is Some(redmine) else { return }
  ensure_time_tracking(redmine)
  let activities = redmine |> @enumerations.time_entry_activities()
  assert_false(activities.is_empty())
  let activity_id = activities[0].id
  let spent_on = "2031-06-15"
  let created = redmine
    |> @time_entries.create({
      hours: 1.5,
      issue_id: None,
      project_id: Some(1),
      spent_on: Some(spent_on),
      activity_id: Some(activity_id),
      comments: Some("time entries integration test"),
    })
  assert_eq(created.hours, 1.5)
  assert_eq(created.project.id, 1)
  assert_eq(created.activity.id, activity_id)
  assert_eq(created.spent_on, spent_on)
  let listed = redmine
    |> @time_entries.list({
      project_id: Some(1),
      user_id: None,
      spent_on: None,
      from: Some(spent_on),
      to: Some(spent_on),
    })
  assert_true(listed.any(fn(entry) { entry.id == created.id }))
  assert_eq(redmine |> @time_entries.show(created.id), created)
  redmine
  |> @time_entries.update(created.id, {
    hours: Some(2.0),
    issue_id: None,
    project_id: None,
    spent_on: None,
    activity_id: None,
    comments: None,
  })
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
