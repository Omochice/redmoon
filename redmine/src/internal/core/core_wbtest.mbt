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

///|
fn test_connection() -> Connection {
  guard connect("https://redmine.example.com/redmine", "secret-key")
    is Some(conn) else {
    abort("the endpoint does not parse")
  }
  conn
}

///|
test "a client for the endpoint's own origin sends the API key" {
  let headers = client_headers(test_connection(), "https://redmine.example.com")
  assert_eq(headers.get("X-Redmine-API-Key"), Some("secret-key"))
}

///|
test "a client for another spelling of the endpoint's origin sends the API key" {
  let headers = client_headers(
    test_connection(),
    "HTTPS://Redmine.Example.com:443",
  )
  assert_eq(headers.get("X-Redmine-API-Key"), Some("secret-key"))
}

///|
test "a client for another host does not send the API key" {
  let headers = client_headers(test_connection(), "https://cdn.example.com")
  assert_eq(headers.get("X-Redmine-API-Key"), None)
}

///|
test "a client sends the requested Accept header" {
  let headers = client_headers(
    test_connection(),
    "https://redmine.example.com",
    accept="application/json",
  )
  assert_eq(headers.get("Accept"), Some("application/json"))
}

///|
test "a client sends no Accept header unless one is requested" {
  let headers = client_headers(test_connection(), "https://redmine.example.com")
  assert_eq(headers.get("Accept"), None)
}
