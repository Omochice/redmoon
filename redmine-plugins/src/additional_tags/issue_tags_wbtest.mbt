///|
test "an issue answer is read down to its tag names" {
  let json = @json.parse(
    (
      #|{"issue":{"id":42,"subject":"s","tags":[{"id":1,"name":"alpha"}]}}
    ),
  )
  let names = issue_tags_in(json) catch { error => fail(message_of(error)) }
  assert_eq(names, ["alpha"])
}

///|
test "an issue answer without tags names the plugin, its setting, and view_issue_tags" {
  let json = @json.parse(
    (
      #|{"issue":{"id":42,"subject":"s"}}
    ),
  )
  try issue_tags_in(json) catch {
    Decode(message~) =>
      assert_eq(
        message, "The server answered, but the response could not be read: it has no `tags`; the Additional Tags plugin is not installed, its issue tags are switched off, or the user lacks the view_issue_tags permission",
      )
    error => fail(message_of(error))
  } noraise {
    _ => fail("expected the missing tags to be reported")
  }
}

///|
test "the names are written as a tag_list array" {
  assert_eq(
    tag_list_body(["alpha", "Beta Tag"]).stringify(),
    "{\"issue\":{\"tag_list\":[\"alpha\",\"Beta Tag\"]}}",
  )
  assert_eq(tag_list_body([]).stringify(), "{\"issue\":{\"tag_list\":[]}}")
}

///|
test "issues are selected by every name, and by open issues unless a status is given" {
  assert_eq(issues_query(["alpha", "Beta Tag"]), [
    ("set_filter", "1"),
    ("f[]", "tags"),
    ("op[tags]", "="),
    ("v[tags][]", "alpha"),
    ("v[tags][]", "Beta Tag"),
    ("f[]", "status_id"),
    ("op[status_id]", "o"),
  ])
}

///|
test "a status is sent as a status filter, because the shorthand is ignored beside f[]" {
  let cases : Array[(@issues.StatusFilter, Array[(String, String)])] = [
    (Open, [("op[status_id]", "o")]),
    (Closed, [("op[status_id]", "c")]),
    (All, [("op[status_id]", "*")]),
    (Id(5), [("op[status_id]", "="), ("v[status_id][]", "5")]),
  ]
  for entry in cases {
    assert_eq(
      issues_query(["alpha"], status_id=entry.0),
      [
        ("set_filter", "1"),
        ("f[]", "tags"),
        ("op[tags]", "="),
        ("v[tags][]", "alpha"),
        ("f[]", "status_id"),
        ..entry.1,
      ],
    )
  }
}

///|
test "a project narrows the issues as it does for the issue list" {
  let query = issues_query(["alpha"], project_id=3)
  assert_eq(query[query.length() - 1], ("project_id", "3"))
}
