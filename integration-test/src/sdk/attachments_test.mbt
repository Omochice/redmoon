///|
/// The ids of the attachments in an issue answered with `include=attachments`.
/// It reads the raw answer of `@redmine.send` so that the attachments tests do not depend on the issues package.
fn attachment_ids(shown : Json) -> Array[Int32] raise {
  guard shown is { "issue": { "attachments": Array(listed), .. }, .. } else {
    fail("no attachments in \{shown.stringify()}")
  }
  listed.map(attachment => {
    guard attachment is { "id": Number(id, ..), .. } else {
      fail("no id in \{attachment.stringify()}")
    }
    id.to_int()
  })
}

///|
/// The attachments in an issue answered with `include=attachments`, decoded as the SDK decodes an attachment.
/// Decoding the embedded list, rather than reading only the ids, also checks that `Attachment` accepts the shape an issue embeds.
fn listed_attachments(shown : Json) -> Array[@attachments.Attachment] raise {
  guard shown is { "issue": { "attachments": listed, .. }, .. } else {
    fail("no attachments in \{shown.stringify()}")
  }
  @json.from_json(listed)
}

///|
async test "upload, attach, show and download round-trip" {
  let redmine = @livetest.redmine()
  let content = b"attachments round trip\n\x00\xff binary tail"
  let filename = "attachments-live-\{@env.now()}.bin"
  let reader = @io.MemoryReader(w => w.write(content))
  let token = redmine
    |> @attachments.upload(reader, content.length().to_int64(), filename~)
  assert_false(token.is_empty())
  let issue_id = @livetest.create_probe_issue(
    redmine,
    "attachments live \{filename}",
  )
  defer @livetest.delete_probe_issue(redmine, issue_id)
  let _ = @redmine.send(redmine, Put, ["issues", "\{issue_id}.json"], body={
    "issue": { "uploads": [{ "token": token, "filename": filename }] },
  })
  let shown = @redmine.send(redmine, Get, ["issues", "\{issue_id}.json"], query=[
    ("include", "attachments"),
  ])
  let attachments = listed_attachments(shown)
  assert_eq(attachments.length(), 1)
  let attachment = redmine |> @attachments.show(attachments[0].id)
  assert_eq(attachment.filename, filename)
  assert_eq(attachment.filesize, content.length())
  let mut downloaded = b""
  redmine
  |> @attachments.download(attachment.id, (meta, body) => {
    assert_eq(meta.id, attachment.id)
    downloaded = body.read_all().binary()
  })
  assert_eq(downloaded, content)
}

///|
suberror ConsumeFailed

///|
async test "an error raised by consume propagates unchanged" {
  let redmine = @livetest.redmine()
  let content = b"x"
  let reader = @io.MemoryReader(w => w.write(content))
  let filename = "attachments-live-consume-\{@env.now()}.txt"
  let token = redmine |> @attachments.upload(reader, 1L, filename~)
  let issue_id = @livetest.create_probe_issue(
    redmine,
    "attachments consume \{filename}",
  )
  defer @livetest.delete_probe_issue(redmine, issue_id)
  let _ = @redmine.send(redmine, Put, ["issues", "\{issue_id}.json"], body={
    "issue": { "uploads": [{ "token": token, "filename": filename }] },
  })
  let shown = @redmine.send(redmine, Get, ["issues", "\{issue_id}.json"], query=[
    ("include", "attachments"),
  ])
  let attachments = listed_attachments(shown)
  try
    redmine
    |> @attachments.download(attachments[0].id, (_, _) => raise ConsumeFailed)
  catch {
    ConsumeFailed => ()
    _ => fail("expected ConsumeFailed")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
async test "downloading a missing attachment raises Response 404" {
  let redmine = @livetest.redmine()
  try
    redmine |> @attachments.download(0, (_, _) => fail("unexpected content"))
  catch {
    @redmine.Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
async test "show returns an attachment whose content type Redmine reports as null" {
  let redmine = @livetest.redmine()
  let content = b"no extension"
  let filename = "attachments-live-noext-\{@env.now()}"
  let reader = @io.MemoryReader(w => w.write(content))
  let token = redmine
    |> @attachments.upload(reader, content.length().to_int64(), filename~)
  let issue_id = @livetest.create_probe_issue(
    redmine,
    "attachments noext \{filename}",
  )
  defer @livetest.delete_probe_issue(redmine, issue_id)
  let _ = @redmine.send(redmine, Put, ["issues", "\{issue_id}.json"], body={
    "issue": { "uploads": [{ "token": token, "filename": filename }] },
  })
  let shown = @redmine.send(redmine, Get, ["issues", "\{issue_id}.json"], query=[
    ("include", "attachments"),
  ])
  let id = attachment_ids(shown)[0]
  let attachment = redmine |> @attachments.show(id)
  assert_eq(attachment.filename, filename)
  assert_eq(attachment.content_type, None)
}

///|
async test "download streams an attachment whose content type Redmine reports as null" {
  let redmine = @livetest.redmine()
  let content = b"no extension body"
  let filename = "attachments-live-noext-dl-\{@env.now()}"
  let reader = @io.MemoryReader(w => w.write(content))
  let token = redmine
    |> @attachments.upload(reader, content.length().to_int64(), filename~)
  let issue_id = @livetest.create_probe_issue(
    redmine,
    "attachments noext download \{filename}",
  )
  defer @livetest.delete_probe_issue(redmine, issue_id)
  let _ = @redmine.send(redmine, Put, ["issues", "\{issue_id}.json"], body={
    "issue": { "uploads": [{ "token": token, "filename": filename }] },
  })
  let shown = @redmine.send(redmine, Get, ["issues", "\{issue_id}.json"], query=[
    ("include", "attachments"),
  ])
  let id = attachment_ids(shown)[0]
  let mut downloaded = b""
  redmine
  |> @attachments.download(id, (meta, body) => {
    assert_eq(meta.filename, filename)
    downloaded = body.read_all().binary()
  })
  assert_eq(downloaded, content)
}
