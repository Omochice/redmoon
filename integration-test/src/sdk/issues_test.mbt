///|
async test "issues are created, listed, shown, updated, commented and deleted" {
  let redmine = @livetest.redmine()
  let subject = "redmoon-issues-\{@env.now()}"
  let created = redmine
    |> @issues.create(
      @issues.Create::new(
        project_id=1,
        tracker_id=1,
        status_id=1,
        priority_id=2,
        subject~,
        description="first",
        start_date="2026-01-01",
        due_date="2026-01-31",
      ),
    )
  let id = created.id
  let outcome : Error? = try {
    exercise_issue(redmine, created, subject)
    None
  } catch {
    error => Some(error)
  }
  redmine |> @issues.delete(id)
  if outcome is Some(error) {
    raise error
  }
}

///|
async fn exercise_issue(
  redmine : @redmine.Redmine,
  created : @issues.Issue,
  subject : String,
) -> Unit {
  let id = created.id
  assert_eq(created.subject, subject)
  assert_eq(created.start_date, Some("2026-01-01"))

  let listed = redmine
    |> @issues.list(
      @issues.ListQuery::new(
        project_id=1,
        tracker_id=1,
        status_id=Open,
        created_on=Period(Today),
        updated_on=Between(from="2020-01-01", to="2999-01-01"),
        due_date=Past(Since("2026-01-01")),
        includes=[Attachments, Relations],
      ),
    )
  assert_true(listed.any(fn(issue) { issue.id == id }))
  let none = redmine
    |> @issues.list(
      @issues.ListQuery::new(closed_on=Period(Any), status_id=All),
      limit=100,
    )
  assert_false(none.any(fn(issue) { issue.id == id }))

  redmine
  |> @issues.update(
    id,
    @issues.Update::new(
      subject="\{subject}-edited",
      notes="a comment",
      due_date=Clear,
      start_date=Set("2026-02-01"),
      assigned_to_id=Set(1),
    ),
  )
  redmine |> @issues.update(id, @issues.Update::new(assigned_to_id=Clear))
  let shown = redmine
    |> @issues.show(id, includes=[
      Journals,
      Attachments,
      Relations,
      Children,
      Changesets,
      Watchers,
      AllowedStatuses,
    ])
  assert_eq(shown.subject, "\{subject}-edited")
  assert_eq(shown.due_date, None)
  assert_eq(shown.start_date, Some("2026-02-01"))
  assert_eq(shown.assigned_to, None)
  let journals = shown.journals.unwrap()
  let commented = journals
    .iter()
    .find_first(fn(journal) { journal.notes == Some("a comment") })
  guard commented is Some(journal) else { fail("the comment is missing") }

  redmine |> @issues.update_journal(journal.id, notes="edited comment")
  let after_edit = redmine |> @issues.show(id, includes=[Journals])
  assert_true(
    after_edit.journals
    .unwrap()
    .any(fn(j) { j.notes == Some("edited comment") }),
  )
  redmine |> @issues.update_journal(journal.id, private_notes=true)
  redmine |> @issues.update_journal(journal.id, notes="")
}

///|
async test "showing a missing issue raises 404" {
  let redmine = @livetest.redmine()
  try redmine |> @issues.show(2147483647) catch {
    @redmine.Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
/// The id of the saved query `docker/redmine/seed-queries.rb` creates on demo, which differs between instances.
async fn seeded_demo_query(redmine : @redmine.Redmine) -> Int32 {
  guard (redmine |> @queries.list())
    .iter()
    .find_first(q => q.name == "Demo open issues")
    is Some(seeded) else {
    fail("the seeded query is missing; run `task redmine:seed`")
  }
  seeded.id
}

///|
async test "listing issues by a global saved query succeeds" {
  let redmine = @livetest.redmine()
  guard (redmine |> @queries.list())
    .iter()
    .find_first(q => q.project_id is None)
    is Some(global) else {
    fail("no global query")
  }
  ignore(redmine |> @issues.list(@issues.SavedQuery::new(global.id), limit=5))
}

///|
async test "listing issues by a project query under its project returns that project's open issues" {
  let redmine = @livetest.redmine()
  let query_id = seeded_demo_query(redmine)
  let probe = @livetest.create_probe_issue(
    redmine,
    "redmoon-saved-query-\{@env.now()}",
  )
  defer @livetest.delete_probe_issue(redmine, probe)
  let listed = redmine
    |> @issues.list(@issues.SavedQuery::new(query_id, project_id=1))
  assert_true(listed.any(fn(issue) { issue.id == probe }))
  assert_true(listed.all(fn(issue) { issue.project.id == 1 }))
  assert_true(listed.all(fn(issue) { issue.status.is_closed != Some(true) }))
}

///|
async test "listing issues by a project query without its project raises 404" {
  let redmine = @livetest.redmine()
  let query_id = seeded_demo_query(redmine)
  try redmine |> @issues.list(@issues.SavedQuery::new(query_id)) catch {
    @redmine.Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
