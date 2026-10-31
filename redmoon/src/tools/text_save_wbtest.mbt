///|
fn response_fields(called : Called) -> Map[String, Json] raise {
  guard @json.parse(called.text) is Object(fields) else {
    fail("not an object: \{called.text}")
  }
  fields
}

///|
async test "show saves the description and answers with its path in place of the text" {
  let fake = FakeIssues::new()
  fake.description = Some("line one\nline two\n")
  let files = FakeFiles::new()
  let called = call_issues(
    fake,
    { "show": { "id": 4, "description_path": "out/issue-4.md" } },
    files~,
  )
  assert_eq(called.is_error, false, msg=called.text)
  let fields = response_fields(called)
  assert_eq(
    fields.get("description_path"),
    Some(Json::string("/abs/out/issue-4.md")),
  )
  assert_true(!fields.contains("description"))
  assert_eq(fields.get("subject"), Some(Json::string("shown")))
  guard files.saved is [(path, content, _)] else { fail("expected one save") }
  assert_eq(path, "out/issue-4.md")
  assert_eq(content, b"line one\nline two\n")
}

///|
async test "show saves an empty file for an issue without a description" {
  let fake = FakeIssues::new()
  let files = FakeFiles::new()
  let called = call_issues(
    fake,
    { "show": { "id": 4, "description_path": "out/empty.md" } },
    files~,
  )
  assert_eq(called.is_error, false, msg=called.text)
  let fields = response_fields(called)
  assert_eq(
    fields.get("description_path"),
    Some(Json::string("/abs/out/empty.md")),
  )
  assert_true(!fields.contains("description"))
  guard files.saved is [(_, content, _)] else { fail("expected one save") }
  assert_eq(content, b"")
}

///|
async test "show keeps the description in the response without description_path" {
  let fake = FakeIssues::new()
  fake.description = Some("body")
  let files = FakeFiles::new()
  let called = call_issues(fake, { "show": { "id": 4 } }, files~)
  let fields = response_fields(called)
  assert_eq(fields.get("description"), Some(Json::string("body")))
  assert_true(!fields.contains("description_path"))
  assert_eq(files.saved.length(), 0)
}

///|
async test "show answers status 0 when the description file cannot be written" {
  let fake = FakeIssues::new()
  fake.description = Some("body")
  let files = FakeFiles::new(save_failure="out/issue-4.md: file exists")
  let called = call_issues(
    fake,
    { "show": { "id": 4, "description_path": "out/issue-4.md" } },
    files~,
  )
  assert_eq(called.is_error, true)
  assert_eq(called.text, failure_text("out/issue-4.md: file exists"))
}

///|
async test "show offers description_path in readonly mode too" {
  guard advertised_issues(Readonly) is [tool] else { fail("expected one tool") }
  let show = at(tool, ["inputSchema", "properties", "show", "properties"])
  assert_true(at(show, ["description_path"]) is Object(_))
}

///|
async test "wiki show saves the text and answers with its path in place of the text" {
  let fake = FakeWikiPages::new()
  let files = FakeFiles::new()
  let tools = wiki_tools(fake, mode=Readonly, files~)
  let called = call_tool(tools, "redmine_wiki_pages", {
    "show": { "project_id": "demo", "title": "Home", "text_path": "home.md" },
  })
  assert_eq(called.is_error, false, msg=called.text)
  let fields = response_fields(called)
  assert_eq(fields.get("text_path"), Some(Json::string("/abs/home.md")))
  assert_true(!fields.contains("text"))
  guard files.saved is [("home.md", content, _)] else {
    fail("expected one save")
  }
  assert_eq(content, b"hello")
}

///|
async test "wiki show keeps the text without text_path and fails with status 0 when the file cannot be written" {
  let fake = FakeWikiPages::new()
  let kept = call_tool(wiki_tools(fake), "redmine_wiki_pages", {
    "show": { "project_id": "demo", "title": "Home" },
  })
  assert_eq(response_fields(kept).get("text"), Some(Json::string("hello")))
  let refused = call_tool(
    wiki_tools(fake, files=FakeFiles::new(save_failure="home.md: file exists")),
    "redmine_wiki_pages",
    {
      "show": { "project_id": "demo", "title": "Home", "text_path": "home.md" },
    },
  )
  assert_eq(refused.text, failure_text("home.md: file exists"))
}

///|
async test "show saves each CRLF line break as LF and keeps a lone CR" {
  let fake = FakeIssues::new()
  fake.description = Some("one\r\ntwo\rthree\r\n\r\n")
  let files = FakeFiles::new()
  let called = call_issues(
    fake,
    { "show": { "id": 4, "description_path": "out/issue-4.md" } },
    files~,
  )
  assert_eq(called.is_error, false, msg=called.text)
  guard files.saved is [(_, content, _)] else { fail("expected one save") }
  assert_eq(content, b"one\ntwo\rthree\n\n")
}
