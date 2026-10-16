///|
/// A client for the Redmine named by `REDMOON_TEST_ENDPOINT` and `REDMOON_TEST_API_KEY`,
/// or `None` when either is unset so that live tests skip instead of fail.
pub fn redmine() -> @redmine.Redmine? raise @redmine.RedmineError {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return None
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return None
  }
  Some(@redmine.Redmine::new(endpoint~, api_key~))
}

///|
/// Creates a probe issue in the demo project and returns its id.
/// The request is built by hand so that the tests of one resource do not depend on the issues package.
pub async fn create_probe_issue(
  redmine : @redmine.Redmine,
  subject : String,
) -> Int32 raise @redmine.RedmineError {
  let json = @redmine.send(redmine, Post, ["issues.json"], body={
    "issue": {
      "project_id": 1,
      "tracker_id": 1,
      "status_id": 1,
      "priority_id": 2,
      "subject": subject,
    },
  })
  @decode.decode_field(@decode.decode_field(json, "issue"), "id")
}

///|
pub async fn delete_probe_issue(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Unit raise @redmine.RedmineError {
  ignore(@redmine.send(redmine, Delete, ["issues", "\{id}.json"]))
}
