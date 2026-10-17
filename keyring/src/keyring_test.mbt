///|
/// The store is shared with the user and with concurrent runs, so the round trip is
/// opt-in and writes under a service name no other run uses.
fn store_test_service() -> String? {
  guard @env.get_env_var("REDMOON_TEST_KEYRING") is Some("1") else {
    return None
  }
  Some("omochice-keyring-test-\{@env.now()}")
}

///|
test "set, get, list and delete round-trip a secret" {
  guard store_test_service() is Some(service) else { return }
  let account = "alice"
  errdefer (@keyring.delete(service, account) catch { _ => () })
  @keyring.set(service, account, "s3cret-ü")
  assert_eq(@keyring.get(service, account), Some("s3cret-ü"))
  @keyring.set(service, account, "replaced")
  assert_eq(@keyring.get(service, account), Some("replaced"))
  assert_eq(@keyring.list(service), [account])
  @keyring.delete(service, account)
  assert_eq(@keyring.get(service, account), None)
  assert_eq(@keyring.list(service), [])
}
