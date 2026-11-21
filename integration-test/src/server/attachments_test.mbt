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
  defer @livetest.delete_probe_issue(redmine, issue.id)
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

///|
async test "attach a file to a wiki page through the tool" {
  let redmine = @livetest.redmine()
  let project = @redmine.ProjectRef::Identifier("demo")
  let title = "Redmoon tool attach \{@env.now()}"
  redmine |> @wiki.create(project, title, text="h1. Shots")
  defer @livetest.cleanup(() => redmine |> @wiki.delete(project, title))
  let tools = [@tools.attachments_tool(redmine, @tools.LocalFile::new(), Full)]
  with_scratch_dir(async fn(dir) {
    let source = "\{dir}/shot.png"
    let content = b"\x89PNG live wiki attachment"
    @fs.write_file(source, content)
    let attached = call_tool(tools, "redmine_attachments", {
      "attach": { "project_id": "demo", "title": title, "path": source },
    })
    assert_eq(attached.is_error, false)
    assert_eq(
      attached.text,
      "{\"project_id\":\"demo\",\"title\":\"\{title}\",\"filename\":\"shot.png\",\"filesize\":\{content.length()}}",
    )
    let page = redmine |> @wiki.show(project, title, include_attachments=true)
    assert_eq(page.text, "h1. Shots")
    assert_eq(page.version, 1)
    assert_eq(
      page.attachments.map(list => list.map(a => a.filename)),
      Some(["shot.png"]),
    )
  })
}

///|
async test "attach to a missing wiki page answers 404 through the tool and creates nothing" {
  let redmine = @livetest.redmine()
  let project = @redmine.ProjectRef::Identifier("demo")
  let title = "Redmoon tool missing \{@env.now()}"
  defer @livetest.cleanup(() => redmine |> @wiki.delete(project, title))
  let tools = [@tools.attachments_tool(redmine, @tools.LocalFile::new(), Full)]
  with_scratch_dir(async fn(dir) {
    let source = "\{dir}/note.txt"
    @fs.write_file(source, b"note")
    let attached = call_tool(tools, "redmine_attachments", {
      "attach": { "project_id": "demo", "title": title, "path": source },
    })
    assert_eq(attached.is_error, true)
    assert_true(attached.text.contains("\"status\":404"))
  })
  try redmine |> @wiki.show(project, title) catch {
    Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("attach created the page")
  }
}
