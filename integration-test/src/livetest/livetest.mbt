///|
/// It fails rather than skips when a variable is unset, because a test that returns early counts as passed and would hide that nothing reached Redmine.
fn client(key_variable : String) -> @redmine.Redmine raise {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    fail("REDMOON_TEST_ENDPOINT is unset; run `task test:integration`")
  }
  guard @env.get_env_var(key_variable) is Some(api_key) else {
    fail("\{key_variable} is unset; run `task test:integration`")
  }
  @redmine.new(endpoint~, api_key~)
}

///|
/// A client for the Redmine named by `REDMOON_TEST_ENDPOINT`, acting as the administrator whose key is `REDMOON_TEST_API_KEY`.
pub fn redmine() -> @redmine.Redmine raise {
  client("REDMOON_TEST_API_KEY")
}

///|
/// A client for the same Redmine acting as the seeded non-administrator `redmoon-member`, whose key is `REDMOON_TEST_MEMBER_API_KEY`.
/// Some behaviour, such as a plugin dropping a write the user may not make, never happens to an administrator.
pub fn as_member() -> @redmine.Redmine raise {
  client("REDMOON_TEST_MEMBER_API_KEY")
}

///|
/// A client for the same Redmine acting as the seeded non-administrator `redmoon-tagger`, whose key is `REDMOON_TEST_TAGGER_API_KEY`.
/// Unlike `redmoon-member`, it may create tags, so a saved new tag can be told from one an administrator would create anyway.
pub fn as_tagger() -> @redmine.Redmine raise {
  client("REDMOON_TEST_TAGGER_API_KEY")
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
/// Shielded from cancellation, since a cancelled test would otherwise cancel its own cleanup.
pub async fn delete_probe_issue(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Unit nocancel {
  @async.protect_from_cancel(() => {
    ignore(@redmine.send(redmine, Delete, ["issues", "\{id}.json"]))
  })
}
