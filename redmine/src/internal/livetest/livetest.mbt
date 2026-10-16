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
