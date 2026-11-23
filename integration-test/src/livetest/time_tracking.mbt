///|
/// Only the modules are read, because they are the only part of the project this helper changes.
#derive(FromJson)
priv struct TimeEntriesProject {
  enabled_modules : Array[@redmine.IdName]
}

///|
/// Turns on the time tracking module of project 1 when it is off, since Redmine refuses time entries for a project without it.
pub async fn ensure_time_tracking(redmine : @redmine.Redmine) -> Unit {
  let json = redmine
    |> @redmine.send(Get, ["projects", "1.json"], query=[
      ("include", "enabled_modules"),
    ])
  guard json is { "project": project, .. } else {
    fail("no project in \{json.stringify()}")
  }
  let project : TimeEntriesProject = @json.from_json(project)
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
