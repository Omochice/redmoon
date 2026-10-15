///|
async test "live: a paged list honours limit" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = Redmine::new(endpoint~, api_key~)
  let issues : Array[Json] = redmine.list_all(
    ["issues.json"],
    key="issues",
    query=[("status_id", "*")],
    limit=3,
  )
  assert_true(issues.length() <= 3)
}

///|
async test "live: a missing record raises Response 404" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = Redmine::new(endpoint~, api_key~)
  try redmine.get(["issues", "0.json"]) catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
