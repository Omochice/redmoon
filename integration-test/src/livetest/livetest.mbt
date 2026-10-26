///|
/// A client for the Redmine named by `REDMOON_TEST_ENDPOINT` and `REDMOON_TEST_API_KEY`.
/// It fails rather than skips when either is unset, because a test that returns early counts as passed and would hide that nothing reached Redmine.
pub fn redmine() -> @redmine.Redmine raise {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    fail("REDMOON_TEST_ENDPOINT is unset; run `task test:integration`")
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    fail("REDMOON_TEST_API_KEY is unset; run `task test:integration`")
  }
  @redmine.new(endpoint~, api_key~)
}

///|
/// Creates a probe issue in the demo project and returns its id.
/// The request is built by hand so that the tests of one resource do not depend on the issues package.
pub async fn create_probe_issue(
  redmine : @redmine.Redmine,
  subject : String,
  description? : String,
) -> Int32 {
  let issue : Map[String, Json] = {
    "project_id": 1,
    "tracker_id": 1,
    "status_id": 1,
    "priority_id": 2,
    "subject": Json(subject),
  }
  if description is Some(description) {
    issue["description"] = Json(description)
  }
  let json = @redmine.send(redmine, Post, ["issues.json"], body={
    "issue": Json(issue),
  })
  guard json is { "issue": { "id": Number(id, ..), .. }, .. } else {
    fail("no issue id in \{json.stringify()}")
  }
  id.to_int()
}

///|
/// Deletes the probe issue `id`; tests call it from `defer` so that a failed assertion
/// does not leave the issue behind.
pub async fn delete_probe_issue(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Unit raise @redmine.RedmineError {
  ignore(@redmine.send(redmine, Delete, ["issues", "\{id}.json"]))
}
