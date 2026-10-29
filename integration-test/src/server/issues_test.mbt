///|
fn with_field(base : Json, name : String, value : Json) -> Json {
  guard base is Object(fields) else { abort("not an object") }
  let merged : Map[String, Json] = Map([])
  for key, existing in fields {
    merged[key] = existing
  }
  merged[name] = value
  Json::object(merged)
}

///|
async test "issues are created, shown, updated, commented and deleted through the tool" {
  let redmine = @livetest.redmine()
  let tools = [@tools.issues_tool(redmine, @tools.LocalFile::new(), Full)]
  let subject = "redmoon-issues-tool-\{@env.now()}"
  let created = call_tool(tools, "redmine_issues", {
    "create": {
      "project_id": 1,
      "tracker_id": 1,
      "status_id": 1,
      "priority_id": 2,
      "subject": subject,
      "start_date": "2026-01-01",
    },
  })
  assert_eq(created.is_error, false, msg=created.text)
  guard @json.parse(created.text) is { "id": Number(id, ..), .. } else {
    fail("no id in \{created.text}")
  }
  let id = id.to_int()
  let outcome : Error? = try {
    exercise_live_issue(tools, id, subject)
    None
  } catch {
    error => Some(error)
  }
  let deleted = call_tool(tools, "redmine_issues", { "delete": { "id": id } })
  assert_eq(deleted.text, "{\"ok\":true}")
  if outcome is Some(error) {
    raise error
  }
  let gone = call_tool(tools, "redmine_issues", { "show": { "id": id } })
  assert_eq(gone.is_error, true)
  assert_true(gone.text.contains("\"status\":404"))
}

///|
async fn exercise_live_issue(
  tools : Array[@mcp.Tool],
  id : Int32,
  subject : String,
) -> Unit {
  let listed = call_tool(tools, "redmine_issues", {
    "list": {
      "project_id": 1,
      "status_id": "*",
      "created_on": "today",
      "limit": 100,
    },
  })
  assert_eq(listed.is_error, false, msg=listed.text)
  assert_true(listed.text.contains(subject))
  let updated = call_tool(tools, "redmine_issues", {
    "update": {
      "id": id,
      "subject": subject + "-edited",
      "start_date": null,
      "notes": "a comment",
    },
  })
  assert_eq(updated.text, "{\"ok\":true}")
  let shown = call_tool(tools, "redmine_issues", {
    "show": { "id": id, "include": ["journals"] },
  })
  assert_true(shown.text.contains(subject + "-edited"))
  assert_false(shown.text.contains("\"start_date\":\"2026"))
  guard @json.parse(shown.text)
    is { "journals": [{ "id": Number(journal, ..), .. }, ..], .. } else {
    fail("no journal in \{shown.text}")
  }
  let edited = call_tool(tools, "redmine_issues", {
    "update_note": { "journal_id": journal.to_int(), "notes": "edited comment" },
  })
  assert_eq(edited.text, "{\"ok\":true}")
  let again = call_tool(tools, "redmine_issues", {
    "show": { "id": id, "include": ["journals"] },
  })
  assert_true(again.text.contains("edited comment"))
  let hidden = call_tool(tools, "redmine_issues", {
    "update_note": { "journal_id": journal.to_int(), "private_notes": true },
  })
  assert_eq(hidden.text, "{\"ok\":true}")
  let erased = call_tool(tools, "redmine_issues", {
    "delete_note": { "journal_id": journal.to_int() },
  })
  assert_eq(erased.text, "{\"ok\":true}")
}

///|
/// The id of the seeded custom field `name`, read from the administrator-only
/// listing because the seed order decides it.
async fn seeded_custom_field(
  redmine : @redmine.Redmine,
  name : String,
) -> Int32 {
  guard @redmine.send(redmine, Get, ["custom_fields.json"])
    is { "custom_fields": Array(fields), .. } else {
    fail("no custom_fields listing")
  }
  for field in fields {
    if field is { "id": Number(id, ..), "name": String(found), .. } &&
      found == name {
      return id.to_int()
    }
  }
  fail("custom field \{name} is not seeded; run `task redmine:seed`")
}

///|
fn shown_custom_value(issue : Json, id : Int32) -> Json raise {
  guard issue is { "custom_fields": Array(fields), .. } else {
    fail("no custom_fields in \{issue.stringify()}")
  }
  for field in fields {
    if field is { "id": Number(found, ..), "value": value, .. } &&
      found.to_int() == id {
      return value
    }
  }
  fail("custom field \{id} missing from \{issue.stringify()}")
}

///|
async test "an issue is created with a required custom field and its multi-value field is emptied with null" {
  let redmine = @livetest.redmine()
  let tools = [@tools.issues_tool(redmine, @tools.LocalFile::new(), Full)]
  guard @redmine.send(redmine, Get, ["projects", "demo-custom-fields.json"])
    is { "project": { "id": Number(project_id, ..), .. }, .. } else {
    fail("project demo-custom-fields is not seeded; run `task redmine:seed`")
  }
  let severity = seeded_custom_field(redmine, "redmoon Severity")
  let platforms = seeded_custom_field(redmine, "redmoon Platforms")
  let issue : Json = {
    "project_id": project_id,
    "tracker_id": 1,
    "status_id": 1,
    "priority_id": 2,
    "subject": "redmoon-custom-fields-\{@env.now()}",
  }
  let refused = call_tool(tools, "redmine_issues", { "create": issue })
  if !refused.is_error {
    if @json.parse(refused.text) is { "id": Number(leaked, ..), .. } {
      ignore(
        call_tool(tools, "redmine_issues", {
          "delete": { "id": leaked.to_int() },
        }),
      )
    }
    fail("created without the required field: \{refused.text}")
  }
  assert_true(refused.text.contains("\"status\":422"), msg=refused.text)
  let created = call_tool(tools, "redmine_issues", {
    "create": with_field(issue, "custom_fields", [
      { "id": severity, "value": "high" },
      { "id": platforms, "value": ["linux", "macos"] },
    ]),
  })
  assert_eq(created.is_error, false, msg=created.text)
  let body = @json.parse(created.text)
  guard body is { "id": Number(id, ..), .. } else {
    fail("no id in \{created.text}")
  }
  let id = id.to_int()
  defer ignore(call_tool(tools, "redmine_issues", { "delete": { "id": id } }))
  assert_eq(shown_custom_value(body, severity), "high")
  assert_eq(shown_custom_value(body, platforms), ["linux", "macos"])
  let emptied = call_tool(tools, "redmine_issues", {
    "update": {
      "id": id,
      "custom_fields": [{ "id": platforms, "value": null }],
    },
  })
  assert_eq(emptied.text, "{\"ok\":true}")
  let shown = call_tool(tools, "redmine_issues", { "show": { "id": id } })
  let shown = @json.parse(shown.text)
  assert_eq(shown_custom_value(shown, platforms), [])
  assert_eq(shown_custom_value(shown, severity), "high")
}

///|
async test "issues are listed by a saved query through the tool" {
  let redmine = @livetest.redmine()
  let tools = [@tools.issues_tool(redmine, @tools.LocalFile::new(), Readonly)]
  let queries = call_tool(tools, "redmine_issues", { "list_queries": {} })
  assert_eq(queries.is_error, false, msg=queries.text)
  guard @json.parse(queries.text) is Array(listed) &&
    listed.iter().find_first(q => q is { "name": "Demo open issues", .. })
    is Some({ "id": Number(query_id, ..), .. }) else {
    fail("the seeded query is missing from \{queries.text}")
  }
  let called = call_tool(tools, "redmine_issues", {
    "list": { "query_id": query_id.to_int(), "project_id": 1, "limit": 5 },
  })
  assert_eq(called.is_error, false, msg=called.text)
  guard @json.parse(called.text) is Array(_) else {
    fail("not a listing: \{called.text}")
  }
  let unscoped = call_tool(tools, "redmine_issues", {
    "list": { "query_id": query_id.to_int() },
  })
  assert_eq(unscoped.is_error, true)
  assert_true(unscoped.text.contains("\"status\":404"), msg=unscoped.text)
}

///|
async test "an issue description is read from description_path" {
  let redmine = @livetest.redmine()
  let issue = redmine
    |> @issues.create(
      @issues.Create::new(
        project_id=1,
        tracker_id=1,
        status_id=1,
        priority_id=2,
        subject="description_path live \{@env.now()}",
      ),
    )
  defer ((redmine |> @issues.delete(issue.id)) catch { _ => () })
  let tools = [@tools.issues_tool(redmine, @tools.LocalFile::new(), Full)]
  with_scratch_dir(async fn(dir) {
    let path = "\{dir}/description.md"
    let content = "# Heading\n\nfirst line\nsecond line\n"
    @fs.write_file(path, content)
    let updated = call_tool(tools, "redmine_issues", {
      "update": { "id": issue.id, "description_path": path },
    })
    assert_eq(updated.text, "{\"ok\":true}")
    let shown = redmine |> @issues.show(issue.id)
    let stored = "# Heading\r\n\r\nfirst line\r\nsecond line\r\n"
    assert_eq(shown.description, Some(stored))
  })
}

///|
async test "a description saved by show and sent back from the file is stored unchanged" {
  let redmine = @livetest.redmine()
  let content = "# Heading\n\nfirst line\nsecond line\n"
  let issue = redmine
    |> @issues.create(
      @issues.Create::new(
        project_id=1,
        tracker_id=1,
        status_id=1,
        priority_id=2,
        subject="description round trip \{@env.now()}",
        description=content,
      ),
    )
  defer ((redmine |> @issues.delete(issue.id)) catch { _ => () })
  let stored = (redmine |> @issues.show(issue.id)).description
  let tools = [@tools.issues_tool(redmine, @tools.LocalFile::new(), Full)]
  with_scratch_dir(async fn(dir) {
    let path = "\{dir}/description.md"
    let shown = call_tool(tools, "redmine_issues", {
      "show": { "id": issue.id, "description_path": path },
    })
    assert_eq(shown.is_error, false, msg=shown.text)
    guard @json.parse(shown.text) is Object(fields) else {
      fail("not an object: \{shown.text}")
    }
    assert_true(fields.get("description_path") is Some(String(_)))
    assert_false(fields.contains("description"))
    assert_eq(@fs.read_file(path).text(), content)
    let updated = call_tool(tools, "redmine_issues", {
      "update": { "id": issue.id, "description_path": path },
    })
    assert_eq(updated.text, "{\"ok\":true}")
    assert_eq((redmine |> @issues.show(issue.id)).description, stored)
  })
}
