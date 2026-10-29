///|
let one_mib : Int32 = 1048576

///|
fn failure_text(message : String) -> String {
  let payload : Json = { "status": 0, "errors": [message] }
  payload.stringify()
}

///|
async fn create_described_by(files : FakeFiles) -> (FakeIssues, Called) {
  let fake = FakeIssues::new()
  let called = call_issues(
    fake,
    { "create": with_field(new_issue, "description_path", "/tmp/body.md") },
    files~,
  )
  (fake, called)
}

///|
async test "create sends the description_path file byte for byte, trailing newline included" {
  let files = FakeFiles::new(content=b"line one\nline two\n")
  let (fake, called) = create_described_by(files)
  assert_eq(called.is_error, false, msg=called.text)
  assert_eq(fake.created.unwrap().description, Some("line one\nline two\n"))
  assert_eq(files.closed, 1)
}

///|
async test "update sends the description_path and notes_path files" {
  let fake = FakeIssues::new()
  let files = FakeFiles::new(content=b"from file\n")
  let called = call_issues(
    fake,
    {
      "update": {
        "id": 3,
        "description_path": "/tmp/body.md",
        "notes_path": "/tmp/notes.md",
      },
    },
    files~,
  )
  assert_eq(called.is_error, false, msg=called.text)
  let (id, update) = fake.updated.unwrap()
  assert_eq(id, 3)
  assert_eq(update.description, Some("from file\n"))
  assert_eq(update.notes, Some("from file\n"))
  assert_eq(files.closed, 2)
}

///|
async test "update_note sends the notes_path file, optionally with its privacy" {
  let fake = FakeIssues::new()
  let files = FakeFiles::new(content=b"edited\n")
  ignore(
    call_issues(
      fake,
      { "update_note": { "journal_id": 1, "notes_path": "/tmp/n.md" } },
      files~,
    ),
  )
  assert_eq(fake.journal.unwrap(), (1, Some("edited\n"), None))
  ignore(
    call_issues(
      fake,
      {
        "update_note": {
          "journal_id": 2,
          "notes_path": "/tmp/n.md",
          "private_notes": true,
        },
      },
      files~,
    ),
  )
  assert_eq(fake.journal.unwrap(), (2, Some("edited\n"), Some(true)))
  assert_eq(files.closed, 2)
}

///|
async test "update_note refuses a blank notes_path file, which would erase the comment" {
  for content in [b"", b"\n", b" \t\r\n"] {
    let fake = FakeIssues::new()
    let files = FakeFiles::new(content~)
    let called = call_issues(
      fake,
      { "update_note": { "journal_id": 1, "notes_path": "/tmp/n.md" } },
      files~,
    )
    assert_eq(
      called.text,
      failure_text("invalid arguments: update_note.notes: must not be blank"),
    )
    assert_true(fake.journal is None)
    assert_eq(files.closed, 1)
  }
}

///|
async test "a text field given together with its file is rejected before Redmine is asked" {
  let cases : Array[(Json, String)] = [
    (
      {
        "create": with_field(
          with_field(new_issue, "description", "inline"),
          "description_path",
          "/tmp/body.md",
        ),
      },
      "create.description_path: `description` and `description_path` cannot be given together",
    ),
    (
      {
        "update": {
          "id": 1,
          "description": "inline",
          "description_path": "/tmp/body.md",
        },
      },
      "update.description_path: `description` and `description_path` cannot be given together",
    ),
    (
      { "update": { "id": 1, "notes": "inline", "notes_path": "/tmp/n.md" } },
      "update.notes_path: `notes` and `notes_path` cannot be given together",
    ),
    (
      {
        "update_note": {
          "journal_id": 1,
          "notes": "inline",
          "notes_path": "/tmp/n.md",
        },
      },
      "update_note.notes_path: unknown field",
    ),
  ]
  for case in cases {
    let (arguments, message) = case
    let fake = FakeIssues::new()
    let files = FakeFiles::new()
    let called = call_issues(fake, arguments, files~)
    assert_eq(called.text, failure_text("invalid arguments: \{message}"))
    assert_true(
      fake.created is None && fake.updated is None && fake.journal is None,
    )
    assert_eq(files.closed, 0)
  }
}

///|
async test "an invalid argument beside a file is reported without opening the file" {
  let fake = FakeIssues::new()
  let files = FakeFiles::new()
  let called = call_issues(
    fake,
    { "update": { "id": 0, "description_path": "/tmp/body.md" } },
    files~,
  )
  assert_true(
    called.text.contains("invalid arguments: update.id"),
    msg=called.text,
  )
  assert_true(fake.updated is None)
  assert_eq(files.closed, 0)
}

///|
async test "a file over 1 MiB is refused before it is read" {
  let files = FakeFiles::new(content=Bytes::make(one_mib + 1, b'a'))
  let (fake, called) = create_described_by(files)
  assert_eq(
    called.text,
    failure_text(
      "/tmp/body.md is 1048577 bytes, which exceeds the limit of 1048576 bytes (1 MiB)",
    ),
  )
  assert_true(fake.created is None)
  assert_eq(files.closed, 1)
}

///|
async test "a file of exactly 1 MiB is sent" {
  let files = FakeFiles::new(content=Bytes::make(one_mib, b'a'))
  let (fake, called) = create_described_by(files)
  assert_eq(called.is_error, false, msg=called.text)
  assert_eq(fake.created.unwrap().description.unwrap().length(), one_mib)
}

///|
async test "a file that grows past 1 MiB while it is read is refused" {
  let files = FakeFiles::new(
    content=Bytes::make(one_mib + 1, b'a'),
    declared_size=1L,
  )
  let (fake, called) = create_described_by(files)
  assert_eq(
    called.text,
    failure_text("/tmp/body.md exceeds the limit of 1048576 bytes (1 MiB)"),
  )
  assert_true(fake.created is None)
  assert_eq(files.closed, 1)
}

///|
async test "a file that is not UTF-8 is refused" {
  let files = FakeFiles::new(content=b"\xff\xfe")
  let (fake, called) = create_described_by(files)
  assert_eq(called.text, failure_text("/tmp/body.md is not valid UTF-8"))
  assert_true(fake.created is None)
  assert_eq(files.closed, 1)
}

///|
async test "a file that cannot be opened is refused" {
  let files = FakeFiles::new(open_failure="/tmp/body.md: no such file")
  let (fake, called) = create_described_by(files)
  assert_eq(called.text, failure_text("/tmp/body.md: no such file"))
  assert_true(fake.created is None)
}

///|
async test "wiki create and update send the text_path file" {
  let fake = FakeWikiPages::new()
  let files = FakeFiles::new(content=b"body\n")
  let tools = wiki_tools(fake, files~)
  let created = call_tool(tools, "redmine_wiki_pages", {
    "create": { "project_id": "demo", "title": "Page", "text_path": "/tmp/p" },
  })
  assert_eq(created.text, "{\"ok\":true}")
  let updated = call_tool(tools, "redmine_wiki_pages", {
    "update": { "project_id": 1, "title": "Page", "text_path": "/tmp/p" },
  })
  assert_eq(updated.text, "{\"ok\":true}")
  assert_eq(fake.calls, [
    "create demo Page body\n - -", "update 1 Page body\n - - -",
  ])
  assert_eq(files.closed, 2)
}

///|
async test "wiki create and update need exactly one of text and text_path" {
  let fake = FakeWikiPages::new()
  let files = FakeFiles::new()
  let tools = wiki_tools(fake, files~)
  for action in ["create", "update"] {
    let neither = call_tool(
      tools,
      "redmine_wiki_pages",
      single(action, { "project_id": 1, "title": "T" }),
    )
    assert_eq(
      neither.text,
      failure_text(
        "invalid arguments: \{action}.text_path: one of `text` and `text_path` is required",
      ),
    )
    let both = call_tool(
      tools,
      "redmine_wiki_pages",
      single(action, {
        "project_id": 1,
        "title": "T",
        "text": "x",
        "text_path": "/tmp/p",
      }),
    )
    assert_eq(
      both.text,
      failure_text(
        "invalid arguments: \{action}.text_path: `text` and `text_path` cannot be given together",
      ),
    )
  }
  assert_eq(fake.calls, [])
  assert_eq(files.closed, 0)
}

///|
async test "a wiki text_path that cannot be read is refused" {
  let fake = FakeWikiPages::new()
  let tools = wiki_tools(fake, files=FakeFiles::new(content=b"\xc3"))
  let called = call_tool(tools, "redmine_wiki_pages", {
    "update": { "project_id": 1, "title": "Page", "text_path": "/tmp/p" },
  })
  assert_eq(called.text, failure_text("/tmp/p is not valid UTF-8"))
  assert_eq(fake.calls, [])
}

///|
async test "a leading UTF-8 byte order mark is dropped from the file" {
  let files = FakeFiles::new(content=b"\xef\xbb\xbfh1. Title\n")
  let (fake, called) = create_described_by(files)
  assert_eq(called.is_error, false, msg=called.text)
  assert_eq(fake.created.unwrap().description, Some("h1. Title\n"))
}
