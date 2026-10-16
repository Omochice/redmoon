///|
struct FakeAttachments {
  failure : @redmine.RedmineError?
  content : Bytes
  declared_size : Int32
  uploads : Array[(Int64, String)]
  updates : Array[(Int32, @issues.Update)]
}

///|
fn FakeAttachments::new(
  failure? : @redmine.RedmineError,
  content~ : Bytes = b"hello",
  declared_size~ : Int32 = 5,
) -> FakeAttachments {
  { failure, content, declared_size, uploads: [], updates: [], }
}

///|
fn FakeAttachments::check(
  self : FakeAttachments,
) -> Unit raise @redmine.RedmineError {
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn fake_attachment(filesize : Int32) -> @attachments.Attachment {
  {
    id: 7,
    filename: "report.txt",
    filesize,
    content_type: "text/plain",
    description: None,
    content_url: "http://redmine.test/attachments/download/7/report.txt",
    thumbnail_url: None,
    author: { id: 1, name: "Admin", },
    created_on: "2026-01-01T00:00:00Z",
  }
}

///|
impl AttachmentPort for FakeAttachments with fn show_attachment(self, _) {
  self.check()
  fake_attachment(self.declared_size)
}

///|
impl AttachmentPort for FakeAttachments with fn download_attachment(
  self,
  _,
  consume,
) {
  self.check()
  let reader = @io.MemoryReader(w => w.write(self.content))
  defer reader.close()
  consume(fake_attachment(self.declared_size), reader)
}

///|
impl AttachmentPort for FakeAttachments with fn upload_file(
  self,
  reader,
  size,
  filename,
) {
  self.check()
  guard drain(reader) == self.content else { abort("uploaded bytes differ") }
  self.uploads.push((size, filename))
  "token-1"
}

///|
impl AttachmentPort for FakeAttachments with fn attach_uploads(
  self,
  issue_id,
  update,
) {
  self.check()
  self.updates.push((issue_id, update))
}

///|
async fn drain(reader : &@io.Reader) -> Bytes noraise {
  reader.read_all().binary() catch {
    error => abort("\{error}")
  }
}

///|
struct FakeFiles {
  saved : Array[(String, Bytes, Int64)]
  save_failure : String?
  open_failure : String?
  content : Bytes
  mut closed : Int32
}

///|
fn FakeFiles::new(
  save_failure? : String,
  open_failure? : String,
  content~ : Bytes = b"hello",
) -> FakeFiles {
  { saved: [], save_failure, open_failure, content, closed: 0, }
}

///|
impl FilePort for FakeFiles with fn save(self, path, reader, max_size) {
  if self.save_failure is Some(message) {
    raise FileError(message~)
  }
  self.saved.push((path, drain(reader), max_size))
  "/abs/" + path
}

///|
impl FilePort for FakeFiles with fn open(self, path) {
  if self.open_failure is Some(message) {
    raise FileError(message~)
  }
  let reader = @io.MemoryReader(w => w.write(self.content))
  {
    filename: last_segment(path),
    size: self.content.length().to_int64(),
    reader,
    close: () => {
      reader.close()
      self.closed += 1
    },
  }
}

///|
fn attachments_for(
  port : FakeAttachments,
  files : FakeFiles,
  mode~ : Mode = Full,
) -> Array[@mcp.Tool] {
  [attachments_tool(port, files, mode)]
}

///|
async test "show answers the attachment metadata" {
  let called = call_tool(
    attachments_for(FakeAttachments::new(), FakeFiles::new()),
    "redmine_attachments",
    { "show": { "id": 7 } },
  )
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"filename\":\"report.txt\""))
  assert_true(called.text.contains("\"content_type\":\"text/plain\""))
}

///|
async test "download saves the stream and answers the written file" {
  let files = FakeFiles::new()
  let called = call_tool(
    attachments_for(FakeAttachments::new(), files),
    "redmine_attachments",
    { "download": { "id": 7, "path": "out/report.txt" } },
  )
  assert_eq(called.is_error, false)
  assert_eq(
    called.text,
    "{\"path\":\"/abs/out/report.txt\",\"filename\":\"report.txt\",\"content_type\":\"text/plain\",\"filesize\":5}",
  )
  assert_eq(files.saved.length(), 1)
  assert_eq(files.saved[0], ("out/report.txt", b"hello", 524288000L))
}

///|
async test "download passes max_size to the file port" {
  let files = FakeFiles::new()
  let called = call_tool(
    attachments_for(FakeAttachments::new(), files),
    "redmine_attachments",
    { "download": { "id": 7, "path": "a", "max_size": 5 } },
  )
  assert_eq(called.is_error, false)
  assert_eq(files.saved[0].2, 5L)
}

///|
async test "download refuses a declared size above max_size before saving" {
  let files = FakeFiles::new()
  let called = call_tool(
    attachments_for(FakeAttachments::new(), files),
    "redmine_attachments",
    { "download": { "id": 7, "path": "a", "max_size": 4 } },
  )
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"attachment 7 is 5 bytes, which exceeds the max_size limit of 4 bytes\"]}",
  )
  assert_eq(files.saved.length(), 0)
}

///|
async test "download reports a file failure with status 0" {
  let called = call_tool(
    attachments_for(
      FakeAttachments::new(),
      FakeFiles::new(save_failure="a: file exists"),
    ),
    "redmine_attachments",
    { "download": { "id": 7, "path": "a" } },
  )
  assert_eq(called.is_error, true)
  assert_eq(called.text, "{\"status\":0,\"errors\":[\"a: file exists\"]}")
}

///|
async test "download reports a Redmine failure" {
  let files = FakeFiles::new()
  let called = call_tool(
    attachments_for(
      FakeAttachments::new(failure=Response(status=404, errors=["Not found"])),
      files,
    ),
    "redmine_attachments",
    { "download": { "id": 7, "path": "a" } },
  )
  assert_eq(called.is_error, true)
  assert_eq(called.text, "{\"status\":404,\"errors\":[\"Not found\"]}")
  assert_eq(files.saved.length(), 0)
}

///|
async test "show reports a Redmine failure" {
  let called = call_tool(
    attachments_for(
      FakeAttachments::new(failure=Response(status=403, errors=["Forbidden"])),
      FakeFiles::new(),
    ),
    "redmine_attachments",
    { "show": { "id": 7 } },
  )
  assert_eq(called.text, "{\"status\":403,\"errors\":[\"Forbidden\"]}")
}

///|
async test "attach uploads the file and updates the issue" {
  let port = FakeAttachments::new()
  let files = FakeFiles::new()
  let called = call_tool(attachments_for(port, files), "redmine_attachments", {
    "attach": {
      "issue_id": 3,
      "path": "/tmp/dir/data.bin",
      "filename": "renamed.bin",
      "description": "d",
      "notes": "n",
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(
    called.text,
    "{\"issue_id\":3,\"filename\":\"renamed.bin\",\"filesize\":5}",
  )
  assert_eq(port.uploads, [(5L, "renamed.bin")])
  assert_eq(port.updates.length(), 1)
  assert_eq(port.updates[0].0, 3)
  let update = port.updates[0].1
  assert_eq(update.notes, Some("n"))
  assert_eq(
    update.uploads,
    Some([
      @issues.UploadToken::new(
        "token-1",
        filename="renamed.bin",
        description="d",
      ),
    ]),
  )
  assert_eq(files.closed, 1)
}

///|
async test "attach names the upload after the last path segment" {
  for path in ["/a/b/c.txt", "C:\\a\\b\\c.txt", "c.txt", "/a\\b/c.txt"] {
    let port = FakeAttachments::new()
    let called = call_tool(
      attachments_for(port, FakeFiles::new()),
      "redmine_attachments",
      { "attach": { "issue_id": 3, "path": path } },
    )
    assert_eq(called.is_error, false)
    assert_eq(port.uploads, [(5L, "c.txt")])
  }
}

///|
async test "attach reports a missing file with status 0" {
  let port = FakeAttachments::new()
  let called = call_tool(
    attachments_for(port, FakeFiles::new(open_failure="nope: not found")),
    "redmine_attachments",
    { "attach": { "issue_id": 3, "path": "nope" } },
  )
  assert_eq(called.text, "{\"status\":0,\"errors\":[\"nope: not found\"]}")
  assert_eq(port.uploads.length(), 0)
}

///|
async test "attach reports a Redmine failure and still closes the file" {
  let files = FakeFiles::new()
  let called = call_tool(
    attachments_for(
      FakeAttachments::new(failure=Response(status=422, errors=["Invalid"])),
      files,
    ),
    "redmine_attachments",
    { "attach": { "issue_id": 3, "path": "f" } },
  )
  assert_eq(called.text, "{\"status\":422,\"errors\":[\"Invalid\"]}")
  assert_eq(files.closed, 1)
}

///|
async test "arguments are validated" {
  let tools = attachments_for(FakeAttachments::new(), FakeFiles::new())
  let cases : Array[Json] = [
    { "show": { "id": 0 } },
    { "show": {} },
    { "download": { "id": 7, "path": " " } },
    { "download": { "id": 7, "path": "a", "max_size": 0 } },
    { "download": { "id": 7, "path": "a", "max_size": 1.5 } },
    { "download": { "id": 7, "path": "a", "maxSize": 5 } },
    { "attach": { "issue_id": 3, "path": "" } },
    { "attach": { "issue_id": 3, "path": "a", "filename": "  " } },
    { "attach": { "path": "a" } },
  ]
  let messages = []
  for arguments in cases {
    let called = call_tool(tools, "redmine_attachments", arguments)
    assert_eq(called.is_error, true)
    messages.push(called.text)
  }
  assert_eq(messages, [
    "{\"status\":0,\"errors\":[\"invalid arguments: show.id: must be at least 1\"]}",
    "{\"status\":0,\"errors\":[\"invalid arguments: show.id: is required\"]}", "{\"status\":0,\"errors\":[\"invalid arguments: download.path: must not be blank\"]}",
    "{\"status\":0,\"errors\":[\"invalid arguments: download.max_size: must be at least 1\"]}",
    "{\"status\":0,\"errors\":[\"invalid arguments: download.max_size: expected an integer\"]}",
    "{\"status\":0,\"errors\":[\"invalid arguments: download.maxSize: unknown field\"]}",
    "{\"status\":0,\"errors\":[\"invalid arguments: attach.path: must not be blank\"]}",
    "{\"status\":0,\"errors\":[\"invalid arguments: attach.filename: must not be blank\"]}",
    "{\"status\":0,\"errors\":[\"invalid arguments: attach.issue_id: is required\"]}",
  ])
}

///|
async test "readonly drops attach from the schema and the description" {
  let restricted = attachments_for(
    FakeAttachments::new(),
    FakeFiles::new(),
    mode=Readonly,
  )
  let called = call_tool(restricted, "redmine_attachments", {
    "attach": { "issue_id": 3, "path": "a" },
  })
  assert_eq(called.is_error, true)
  assert_true(called.text.contains("unknown action `attach`"))
  let listed = list_tools(restricted).stringify()
  assert_false(listed.contains("attach\\\""))
  assert_false(listed.contains("`attach`"))
  let downloaded = call_tool(restricted, "redmine_attachments", {
    "download": { "id": 7, "path": "a" },
  })
  assert_eq(downloaded.is_error, false)
}

///|
async test "tools/list advertises each mode" {
  let full = list_tools(
    attachments_for(FakeAttachments::new(), FakeFiles::new()),
  )
  let restricted_listing = list_tools(
    attachments_for(FakeAttachments::new(), FakeFiles::new(), mode=Readonly),
  )
  inspect(
    full.stringify(),
    content=(
      #|{"tools":[{"name":"redmine_attachments","description":"Reads Redmine attachments: `show` returns the metadata of one attachment, and `download` saves its content to a local file. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.\nCall `show` first to inspect `filesize` and `content_type`, since the content is never returned inline.\n`download` takes `path`, the destination file path to write (absolute is recommended); it never overwrites a file that already exists, and answers with the path it wrote plus the filename, content type, and size.\n`max_size` bounds how many bytes may be written, 500 MiB by default; pass a smaller limit when the attachment should be refused above it, reading `filesize` from `show` to choose one.\n`attach` adds a local file to an issue: it takes `path`, the local file to send (absolute is recommended), and `issue_id`, the existing issue to add it to; `notes` adds a comment in the same history entry. To attach a file to a new issue, create the issue with `redmine_issues` first.","inputSchema":{"type":"object","properties":{"show":{"type":"object","properties":{"id":{"type":"integer","minimum":1}},"required":["id"],"additionalProperties":false},"download":{"type":"object","properties":{"id":{"type":"integer","minimum":1},"path":{"type":"string","pattern":"\\S","description":"Destination file path for the saved content. An absolute path is recommended, because a relative one resolves against the working directory of the server process. The file must not already exist."},"max_size":{"type":"integer","minimum":1,"description":"Maximum number of bytes to write, 524288000 (500 MiB) by default. The download is refused, and nothing is saved, when the attachment turns out to be larger. Read `filesize` from `show` to choose a tighter limit.","default":524288000}},"required":["id","path"],"additionalProperties":false},"attach":{"type":"object","properties":{"issue_id":{"type":"integer","minimum":1},"path":{"type":"string","pattern":"\\S","description":"Local file to attach. An absolute path is recommended, because a relative one resolves against the working directory of the server process."},"filename":{"type":"string","pattern":"\\S","description":"Name the attachment is shown under; the last segment of `path` by default."},"description":{"type":"string"},"notes":{"type":"string","description":"Comment to add to the issue in the same history entry as the attachment."}},"required":["issue_id","path"],"additionalProperties":false}},"minProperties":1,"maxProperties":1,"additionalProperties":false}}]}
    ),
  )
  inspect(
    restricted_listing.stringify(),
    content=(
      #|{"tools":[{"name":"redmine_attachments","description":"Reads Redmine attachments: `show` returns the metadata of one attachment, and `download` saves its content to a local file. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.\nCall `show` first to inspect `filesize` and `content_type`, since the content is never returned inline.\n`download` takes `path`, the destination file path to write (absolute is recommended); it never overwrites a file that already exists, and answers with the path it wrote plus the filename, content type, and size.\n`max_size` bounds how many bytes may be written, 500 MiB by default; pass a smaller limit when the attachment should be refused above it, reading `filesize` from `show` to choose one.","inputSchema":{"type":"object","properties":{"show":{"type":"object","properties":{"id":{"type":"integer","minimum":1}},"required":["id"],"additionalProperties":false},"download":{"type":"object","properties":{"id":{"type":"integer","minimum":1},"path":{"type":"string","pattern":"\\S","description":"Destination file path for the saved content. An absolute path is recommended, because a relative one resolves against the working directory of the server process. The file must not already exist."},"max_size":{"type":"integer","minimum":1,"description":"Maximum number of bytes to write, 524288000 (500 MiB) by default. The download is refused, and nothing is saved, when the attachment turns out to be larger. Read `filesize` from `show` to choose a tighter limit.","default":524288000}},"required":["id","path"],"additionalProperties":false}},"minProperties":1,"maxProperties":1,"additionalProperties":false}}]}
    ),
  )
}

///|
test "last_segment handles both separators" {
  assert_eq(last_segment("a/b/c"), "c")
  assert_eq(last_segment("a\\b\\c"), "c")
  assert_eq(last_segment("a/b\\c"), "c")
  assert_eq(last_segment("a\\b/c"), "c")
  assert_eq(last_segment("c"), "c")
}

///|
async fn with_scratch_dir(body : async (String) -> Unit) -> Unit {
  let dir = @fs.tmpdir(prefix="redmoon-attachments-")
  defer @fs.rmdir(dir, recursive=true)
  body(dir)
}

///|
/// The message of the `FileError` that `body` must raise.
async fn file_error_message(body : async () -> Unit) -> String {
  try body() catch {
    FileError(message~) => message
    other => fail("expected a FileError, got \{other}")
  } noraise {
    _ => fail("expected a FileError")
  }
}

///|
async test "LocalFile saves, refuses to overwrite and bounds the size" {
  with_scratch_dir(async fn(dir) {
    let files = LocalFile::new()
    let path = "\{dir}/out.bin"
    let written = files.save(path, @io.MemoryReader(w => w.write(b"abc")), 3L)
    assert_true(written.has_suffix("/out.bin"))
    assert_eq(@fs.read_file(path).binary(), b"abc")
    let existing = file_error_message(async fn() {
      let reader = @io.MemoryReader(w => w.write(b"zzz"))
      defer reader.close()
      ignore(files.save(path, reader, 10L))
    })
    assert_true(existing.contains(path))
    assert_eq(@fs.read_file(path).binary(), b"abc")
    let big = "\{dir}/big.bin"
    let over = file_error_message(async fn() {
      let reader = @io.MemoryReader(w => w.write(b"abcd"))
      defer reader.close()
      ignore(files.save(big, reader, 3L))
    })
    assert_eq(over, "content exceeds the max_size limit of 3 bytes")
    assert_false(@fs.exists(big))
  })
}

///|
async test "LocalFile opens regular files only" {
  with_scratch_dir(async fn(dir) {
    let files = LocalFile::new()
    let path = "\{dir}/in.bin"
    @fs.write_file(path, b"12345")
    let content = files.open(path)
    assert_eq(content.filename, "in.bin")
    assert_eq(content.size, 5L)
    assert_eq(content.reader.read_all().binary(), b"12345")
    (content.close)()
    let directory = file_error_message(async fn() { ignore(files.open(dir)) })
    assert_true(directory.contains("not a regular file"))
    ignore(
      file_error_message(async fn() { ignore(files.open("\{dir}/missing")) }),
    )
  })
}

///|
async test "live: attach, show and download through the tool" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = @redmine.new(endpoint~, api_key~)
  let issue = redmine
    |> @issues.create(
      @issues.Create::new(
        project_id=1,
        tracker_id=1,
        status_id=1,
        priority_id=2,
        subject="attachments live \{@env.now()}",
      ),
    )
  defer ((redmine |> @issues.delete(issue.id)) catch { _ => () })
  let tools = [attachments_tool(redmine, LocalFile::new(), Full)]
  with_scratch_dir(async fn(dir) {
    let source = "\{dir}/source.bin"
    let content = b"live attachment\n\x00\xff tail"
    @fs.write_file(source, content)
    let attached = call_tool(tools, "redmine_attachments", {
      "attach": { "issue_id": issue.id, "path": source, "notes": "live" },
    })
    assert_eq(attached.is_error, false)
    assert_eq(
      attached.text,
      "{\"issue_id\":\{issue.id},\"filename\":\"source.bin\",\"filesize\":\{content.length()}}",
    )
    let shown_issue = redmine
      |> @issues.show(issue.id, includes=[@issues.Include::Attachments])
    let attachment_id = shown_issue.attachments.unwrap()[0].id
    let shown = call_tool(tools, "redmine_attachments", {
      "show": { "id": attachment_id },
    })
    assert_true(shown.text.contains("\"filename\":\"source.bin\""))
    let target = "\{dir}/copy.bin"
    let downloaded = call_tool(tools, "redmine_attachments", {
      "download": { "id": attachment_id, "path": target },
    })
    assert_eq(downloaded.is_error, false)
    assert_true(downloaded.text.contains("\"filename\":\"source.bin\""))
    assert_eq(@fs.read_file(target).binary(), content)
    let again = call_tool(tools, "redmine_attachments", {
      "download": { "id": attachment_id, "path": target },
    })
    assert_eq(again.is_error, true)
    assert_eq(@fs.read_file(target).binary(), content)
    let small = "\{dir}/small.bin"
    let refused = call_tool(tools, "redmine_attachments", {
      "download": { "id": attachment_id, "path": small, "max_size": 3 },
    })
    assert_eq(refused.is_error, true)
    assert_false(@fs.exists(small))
  })
}

///|
struct StalledDownload {
  started : Ref[Bool]
}

///|
impl AttachmentPort for StalledDownload with fn show_attachment(_, _) {
  abort("unused")
}

///|
impl AttachmentPort for StalledDownload with fn download_attachment(
  self,
  _,
  consume,
) {
  let (reader, writer) = @io.pipe()
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      writer.write(b"abc")
      @async.sleep(60000)
    })
    self.started.val = true
    consume(fake_attachment(5), reader)
  })
}

///|
impl AttachmentPort for StalledDownload with fn upload_file(_, _, _, _) {
  abort("unused")
}

///|
impl AttachmentPort for StalledDownload with fn attach_uploads(_, _, _) {
  abort("unused")
}

///|
async test "cancelling a download writes no response and leaves no partial file" {
  with_scratch_dir(async fn(dir) {
    let target = "\{dir}/out.bin"
    let started = Ref(false)
    let tools = [
      attachments_tool(
        StalledDownload::{ started, },
        LocalFile::new(),
        Readonly,
      ),
    ]
    let output = run_session(new_server(tools), async fn(w) {
      w.write(initialize_line())
      w.write(
        request_line(2, "tools/call", {
          "name": "redmine_attachments",
          "arguments": { "download": { "id": 7, "path": target } },
        }),
      )
      @async.sleep(100)
      w.write(
        (
          {
            "jsonrpc": "2.0",
            "method": "notifications/cancelled",
            "params": { "requestId": 2 },
          } : Json).stringify() +
        "\n",
      )
      w.write(request_line(3, "ping", {}))
    })
    assert_true(started.val)
    assert_false(output.contains("\"id\":2"))
    assert_true(output.contains("\"id\":3"))
    assert_false(@fs.exists(target))
  })
}
