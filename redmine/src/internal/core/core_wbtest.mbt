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

///|
test "a non-2xx answer is rejected with the errors Redmine gave" {
  let body = "{\"errors\":[\"Subject cannot be blank\"]}"
  guard interpret(422, body) is Rejected(status~, errors~) else {
    fail("expected Rejected")
  }
  assert_eq(status, 422)
  assert_eq(errors, ["Subject cannot be blank"])
}

///|
test "an empty 2xx body is null" {
  guard interpret(204, "") is Body(json) else { fail("expected Body") }
  assert_eq(json, Json::null())
}
