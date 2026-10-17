///|
async test "live: a relation links two issues and is listed, shown and deleted" {
  guard @livetest.redmine() is Some(redmine) else { return }
  let nonce = @env.now().to_string()
  let first = @livetest.create_probe_issue(redmine, "relprobe\{nonce}a")
  defer @livetest.delete_probe_issue(redmine, first)
  let second = @livetest.create_probe_issue(redmine, "relprobe\{nonce}b")
  defer @livetest.delete_probe_issue(redmine, second)
  let relation = redmine
    |> @relations.create(
      first,
      issue_to_id=second,
      relation_type=@relations.Type::Blocks,
    )
  assert_eq(relation.issue_id, first)
  assert_eq(relation.issue_to_id, second)
  assert_eq(relation.relation_type, @relations.Type::Blocks)
  assert_true(
    (redmine |> @relations.list(first)).any(fn(r) { r.id == relation.id }),
  )
  assert_eq(redmine |> @relations.show(relation.id), relation)
  redmine |> @relations.delete(relation.id)
  assert_false(
    (redmine |> @relations.list(first)).any(fn(r) { r.id == relation.id }),
  )
}
