///|
test "version is the value stored in version.json" {
  let stored = match @json.parse(version_json) {
    Object({ "version": String(stored), .. }) => stored
    _ => fail("version.json has no string version")
  }
  assert_eq(version, stored)
  assert_true(!stored.is_empty())
}
