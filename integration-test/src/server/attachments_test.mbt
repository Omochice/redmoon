///|
async fn with_scratch_dir(body : async (String) -> Unit) -> Unit {
  let dir = @fs.tmpdir(prefix="redmoon-attachments-")
  defer @fs.rmdir(dir, recursive=true)
  body(dir)
}

///|
async test "attach, show and download through the tool" {
  let redmine = @livetest.redmine()
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
  let tools = [@tools.attachments_tool(redmine, @tools.LocalFile::new(), Full)]
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
