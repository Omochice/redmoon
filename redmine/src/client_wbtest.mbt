///|
async test "a refused connection raises Transport without the API key" {
  let redmine = Redmine::new(
    endpoint="http://127.0.0.1:1",
    api_key="s3cr3t-key",
  )
  try redmine.list_issue_priorities() catch {
    Transport(message~) => assert_false(message.contains("s3cr3t-key"))
    _ => fail("expected Transport")
  } noraise {
    _ => fail("expected an error")
  }
}
