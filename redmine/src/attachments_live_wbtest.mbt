///|
fn attachments_live_redmine() -> Redmine? raise RedmineError {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return None
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return None
  }
  Some(Redmine::new(endpoint~, api_key~))
}

///|
async test "live: upload, attach, show and download round-trip" {
  guard attachments_live_redmine() is Some(redmine) else { return }
  let content = b"attachments round trip\n\x00\xff binary tail"
  let filename = "attachments-live-\{@env.now()}.bin"
  let reader = @io.MemoryReader(w => w.write(content))
  let token = redmine.upload(reader, content.length().to_int64(), filename~)
  assert_false(token.is_empty())
  let created = send(redmine, Post, ["issues.json"], body={
    "issue": { "project_id": 1, "subject": "attachments live \{filename}" },
  })
  let issue_id : Int32 = decode_field(decode_field(created, "issue"), "id")
  defer ignore(send(redmine, Delete, ["issues", "\{issue_id}.json"]))
  let _ = send(redmine, Put, ["issues", "\{issue_id}.json"], body={
    "issue": { "uploads": [{ "token": token, "filename": filename }] },
  })
  let shown = send(redmine, Get, ["issues", "\{issue_id}.json"], query=[
    ("include", "attachments"),
  ])
  let attachments : Array[Attachment] = decode_field(
    decode_field(shown, "issue"),
    "attachments",
  )
  assert_eq(attachments.length(), 1)
  let attachment = redmine.show_attachment(attachments[0].id)
  assert_eq(attachment.filename, filename)
  assert_eq(attachment.filesize, content.length())
  let mut downloaded = b""
  redmine.download_attachment(attachment.id, (meta, body) => {
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
  guard attachments_live_redmine() is Some(redmine) else { return }
  let content = b"x"
  let reader = @io.MemoryReader(w => w.write(content))
  let filename = "attachments-live-consume-\{@env.now()}.txt"
  let token = redmine.upload(reader, 1L, filename~)
  let created = send(redmine, Post, ["issues.json"], body={
    "issue": { "project_id": 1, "subject": "attachments consume \{filename}" },
  })
  let issue_id : Int32 = decode_field(decode_field(created, "issue"), "id")
  defer ignore(send(redmine, Delete, ["issues", "\{issue_id}.json"]))
  let _ = send(redmine, Put, ["issues", "\{issue_id}.json"], body={
    "issue": { "uploads": [{ "token": token, "filename": filename }] },
  })
  let shown = send(redmine, Get, ["issues", "\{issue_id}.json"], query=[
    ("include", "attachments"),
  ])
  let attachments : Array[Attachment] = decode_field(
    decode_field(shown, "issue"),
    "attachments",
  )
  try
    redmine.download_attachment(attachments[0].id, (_, _) => raise ConsumeFailed)
  catch {
    ConsumeFailed => ()
    _ => fail("expected ConsumeFailed")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
async test "live: downloading a missing attachment raises Response 404" {
  guard attachments_live_redmine() is Some(redmine) else { return }
  try
    redmine.download_attachment(0, (_, _) => fail("unexpected content"))
  catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
