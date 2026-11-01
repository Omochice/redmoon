///|
test "a 2xx HTML body is malformed without echoing the body" {
  let html = "<html><body>Sign in to secret-corp</body></html>"
  guard interpret(200, html) is Malformed(message~) else {
    fail("expected Malformed")
  }
  assert_true(message.has_prefix("The server answered"))
  assert_true(message.contains("not JSON"))
  assert_false(message.contains("<"))
  assert_false(message.contains("secret-corp"))
}
