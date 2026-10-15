///|
async test "live: issues are created, listed, shown, updated, commented and deleted" {
  guard live_redmine() is Some(redmine) else { return }
  let subject = "redmoon-issues-\{@env.now()}"
  let created = redmine.create_issue(
    @redmine.IssueCreate::new(
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
  redmine.delete_issue(id)
  if outcome is Some(error) {
    raise error
  }
}

///|
async fn exercise_issue(
  redmine : @redmine.Redmine,
  created : @redmine.Issue,
  subject : String,
) -> Unit {
  let id = created.id
  assert_eq(created.subject, subject)
  assert_eq(created.start_date, Some("2026-01-01"))

  let listed = redmine.list_issues(
    @redmine.IssueListQuery::new(
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
  let none = redmine.list_issues(
    @redmine.IssueListQuery::new(closed_on=Period(Any), status_id=All),
    limit=100,
  )
  assert_false(none.any(fn(issue) { issue.id == id }))

  redmine.update_issue(
    id,
    @redmine.IssueUpdate::new(
      subject="\{subject}-edited",
      notes="a comment",
      due_date=Clear,
      start_date=Set("2026-02-01"),
      assigned_to_id=Set(1),
    ),
  )
  redmine.update_issue(id, @redmine.IssueUpdate::new(assigned_to_id=Clear))
  let shown = redmine.show_issue(id, includes=[
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

  redmine.update_journal(journal.id, notes="edited comment")
  let after_edit = redmine.show_issue(id, includes=[Journals])
  assert_true(
    after_edit.journals
    .unwrap()
    .any(fn(j) { j.notes == Some("edited comment") }),
  )
  redmine.update_journal(journal.id, private_notes=true)
  redmine.update_journal(journal.id, notes="")
}

///|
async test "live: showing a missing issue raises 404" {
  guard live_redmine() is Some(redmine) else { return }
  try redmine.show_issue(2147483647) catch {
    @redmine.Response(status~, ..) => assert_eq(status, 404)
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected an error")
  }
}
