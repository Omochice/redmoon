///|
let test_service : String = "omochice-keyring-test"

///|
let test_account : String = "alice"

///|
test "set, get, list and delete round-trip a secret" {
  try {
    @keyring.delete(test_service, test_account)
    @keyring.set(test_service, test_account, "s3cret-ü")
    assert_eq(@keyring.get(test_service, test_account), Some("s3cret-ü"))
    @keyring.set(test_service, test_account, "replaced")
    assert_eq(@keyring.get(test_service, test_account), Some("replaced"))
    assert_true(@keyring.list(test_service).contains(test_account))
    @keyring.delete(test_service, test_account)
    assert_eq(@keyring.get(test_service, test_account), None)
    assert_false(@keyring.list(test_service).contains(test_account))
  } catch {
    @keyring.NoStore(reason) => println("skipped: no credential store (\{reason})")
    e => {
      @keyring.delete(test_service, test_account) catch { _ => () }
      raise e
    }
  } noraise {
    _ => ()
  }
}
