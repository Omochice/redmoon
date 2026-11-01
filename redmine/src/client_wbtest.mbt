///|
async test "a refused connection raises Transport without the API key" {
  let redmine = new(endpoint="http://127.0.0.1:1", api_key="s3cr3t-key")
  try send(redmine, Get, ["enumerations", "issue_priorities.json"]) catch {
    Transport(message~) => assert_false(message.contains("s3cr3t-key"))
    _ => fail("expected Transport")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "an unusable endpoint raises Transport without echoing it" {
  try new(endpoint="ftp://user:secret@example.com", api_key="k") catch {
    Transport(message~) => assert_false(message.contains("secret"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "a 2xx body that is not JSON raises Decode" {
  try unwrap(@core.interpret(200, "<html></html>")) catch {
    Decode(message~) => assert_true(message.contains("not JSON"))
    error => fail(Json(error).stringify())
  } noraise {
    _ => fail("expected an error")
  }
}
