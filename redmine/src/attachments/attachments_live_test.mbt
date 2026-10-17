///|
async test "live: upload, attach, show and download round-trip" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let content = b"attachments round trip\n\x00\xff binary tail"
  let filename = "attachments-live-\{@env.now()}.bin"
  let reader = @io.MemoryReader(w => w.write(content))
  let token = redmine
    |> @attachments.upload(reader, content.length().to_int64(), filename~)
  assert_false(token.is_empty())
  let created = @redmine.send(redmine, Post, ["issues.json"], body={
    "issue": { "project_id": 1, "subject": "attachments live \{filename}" },
  })
  let issue_id : Int32 = @decode.decode_field(
    @decode.decode_field(created, "issue"),
    "id",
  )
  defer ignore(@redmine.send(redmine, Delete, ["issues", "\{issue_id}.json"]))
  let _ = @redmine.send(redmine, Put, ["issues", "\{issue_id}.json"], body={
    "issue": { "uploads": [{ "token": token, "filename": filename }] },
  })
  let shown = @redmine.send(redmine, Get, ["issues", "\{issue_id}.json"], query=[
    ("include", "attachments"),
  ])
  let attachments : Array[@attachments.Attachment] = @decode.decode_field(
    @decode.decode_field(shown, "issue"),
    "attachments",
  )
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

///|
async test "live: an error raised by consume propagates unchanged" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let content = b"x"
  let reader = @io.MemoryReader(w => w.write(content))
  let filename = "attachments-live-consume-\{@env.now()}.txt"
  let token = redmine |> @attachments.upload(reader, 1L, filename~)
  let created = @redmine.send(redmine, Post, ["issues.json"], body={
    "issue": { "project_id": 1, "subject": "attachments consume \{filename}" },
  })
  let issue_id : Int32 = @decode.decode_field(
    @decode.decode_field(created, "issue"),
    "id",
  )
  defer ignore(@redmine.send(redmine, Delete, ["issues", "\{issue_id}.json"]))
  let _ = @redmine.send(redmine, Put, ["issues", "\{issue_id}.json"], body={
    "issue": { "uploads": [{ "token": token, "filename": filename }] },
  })
  let shown = @redmine.send(redmine, Get, ["issues", "\{issue_id}.json"], query=[
    ("include", "attachments"),
  ])
  let attachments : Array[@attachments.Attachment] = @decode.decode_field(
    @decode.decode_field(shown, "issue"),
    "attachments",
  )
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
async test "live: downloading a missing attachment raises Response 404" {
  guard @livetest.redmine() is Some(redmine) else { return }
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
async test "live: show returns an attachment whose content type Redmine reports as null" {
  guard @livetest.redmine() is Some(redmine) else { return }
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
  let listed : Array[Json] = @decode.decode_field(
    @decode.decode_field(shown, "issue"),
    "attachments",
  )
  let id : Int32 = @decode.decode_field(listed[0], "id")
  let attachment = redmine |> @attachments.show(id)
  assert_eq(attachment.filename, filename)
  assert_eq(attachment.content_type, None)
}

//|
async test "live: download streams an attachment whose content type Redmine reports as null" {
  guard @livetest.redmine() is Some(redmine) else { return }
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
  let listed : Array[Json] = @decode.decode_field(
    @decode.decode_field(shown, "issue"),
    "attachments",
  )
  let id : Int32 = @decode.decode_field(listed[0], "id")
  let mut downloaded = b""
  redmine
  |> @attachments.download(id, (meta, body) => {
    assert_eq(meta.filename, filename)
    downloaded = body.read_all().binary()
  })
  assert_eq(downloaded, content)
}
