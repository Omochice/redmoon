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
  errdefer (@keyring.delete(service~, account~) catch { _ => () })
  @keyring.set(service~, account~, secret="s3cret-ü")
  assert_eq(@keyring.get(service~, account~), Some("s3cret-ü"))
  @keyring.set(service~, account~, secret="replaced")
  assert_eq(@keyring.get(service~, account~), Some("replaced"))
  assert_eq(@keyring.list(service), [account])
  @keyring.delete(service~, account~)
  assert_eq(@keyring.get(service~, account~), None)
  assert_eq(@keyring.list(service), [])
}

///|
test "a refused NUL write leaves the stored secret as it was" {
  guard store_test_service() is Some(service) else { return }
  let account = "alice"
  errdefer (@keyring.delete(service~, account~) catch { _ => () })
  @keyring.set(service~, account~, secret="original")
  try @keyring.set(service~, account~, secret="abc\u{0}def") catch {
    Refused(_) => ()
    _ => fail("raised a different error")
  } noraise {
    _ => fail("a secret containing NUL was accepted")
  }
  assert_eq(@keyring.get(service~, account~), Some("original"))
  @keyring.delete(service~, account~)
}
