///|
/// Only the modules are read, because they are the only part of the project this test changes.
priv struct TimeEntriesProject {
  enabled_modules : Array[IdName]
} derive(FromJson)

///|
/// Turns on the time tracking module of project 1 when it is off, since Redmine refuses time entries for a project without it.
async fn time_entries_ensure_time_tracking(
  redmine : Redmine,
) -> Unit raise RedmineError {
  let json = redmine.get(["projects", "1.json"], query=[
    ("include", "enabled_modules"),
  ])
  let project : TimeEntriesProject = decode_field(json, "project")
  let names = project.enabled_modules.map(fn(enabled) { enabled.name })
  if names.contains("time_tracking") {
    return
  }
  let body_names = names.map(fn(name) { Json::string(name) })
  body_names.push(Json::string("time_tracking"))
  let _ = send(
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
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = Redmine::new(endpoint~, api_key~)
  time_entries_ensure_time_tracking(redmine)
  let activities : Array[IdName] = decode_field(
    send(redmine, Get, ["enumerations", "time_entry_activities.json"]),
    "time_entry_activities",
  )
  assert_false(activities.is_empty())
  let activity_id = activities[0].id
  let spent_on = "2031-06-15"
  let created = redmine.create_time_entry({
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
  let listed = redmine.list_time_entries({
    project_id: Some(1),
    user_id: None,
    spent_on: None,
    from: Some(spent_on),
    to: Some(spent_on),
  })
  assert_true(listed.any(fn(entry) { entry.id == created.id }))
  assert_eq(redmine.show_time_entry(created.id), created)
  redmine.update_time_entry(created.id, {
    hours: Some(2.0),
    issue_id: None,
    project_id: None,
    spent_on: None,
    activity_id: None,
    comments: None,
  })
  let updated = redmine.show_time_entry(created.id)
  assert_eq(updated.hours, 2.0)
  assert_eq(updated.comments, Some("time entries integration test"))
  redmine.delete_time_entry(created.id)
  try redmine.show_time_entry(created.id) catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
