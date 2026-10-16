///|
fn live_redmine() -> @redmine.Redmine? raise @redmine.RedmineError {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return None
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return None
  }
  Some(@redmine.Redmine::new(endpoint~, api_key~))
}
