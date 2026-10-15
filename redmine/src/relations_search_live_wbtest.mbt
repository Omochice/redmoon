///|
/// Returns a client for the test Redmine, or `None` when the test environment is not configured.
fn relations_search_live_redmine() -> Redmine? raise RedmineError {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return None
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return None
  }
  Some(Redmine::new(endpoint~, api_key~))
}

///|
/// Creates a probe issue in the demo project and returns its id.
/// Redmine has no issue operation in this package yet, so the request is built here.
async fn create_probe_issue(
  redmine : Redmine,
  subject : String,
) -> Int32 raise RedmineError {
  let issue : Map[String, Json] = {
    "project_id": ToJson::to_json(1),
    "tracker_id": ToJson::to_json(1),
    "status_id": ToJson::to_json(1),
    "priority_id": ToJson::to_json(2),
    "subject": ToJson::to_json(subject),
  }
  let json = redmine.send(
    Post,
    ["issues.json"],
    body=Json::object({ "issue": Json::object(issue) }),
  )
  let created : Json = decode_field(json, "issue")
  decode_field(created, "id")
}

///|
async fn delete_probe_issue(
  redmine : Redmine,
  id : Int32,
) -> Unit raise RedmineError {
  ignore(redmine.send(Delete, ["issues", "\{id}.json"]))
}

///|
async test "live: a relation links two issues and is listed, shown and deleted" {
  guard relations_search_live_redmine() is Some(redmine) else { return }
  let nonce = @env.now().to_string()
  let first = create_probe_issue(redmine, "relsearch\{nonce}a")
  let second = create_probe_issue(redmine, "relsearch\{nonce}b")
  let relation = redmine.create_relation(
    first,
    issue_to_id=second,
    relation_type=Blocks,
  )
  assert_eq(relation.issue_id, first)
  assert_eq(relation.issue_to_id, second)
  assert_eq(relation.relation_type, Blocks)
  assert_true(redmine.list_relations(first).any(fn(r) { r.id == relation.id }))
  assert_eq(redmine.show_relation(relation.id), relation)
  redmine.delete_relation(relation.id)
  assert_false(redmine.list_relations(first).any(fn(r) { r.id == relation.id }))
  delete_probe_issue(redmine, first)
  delete_probe_issue(redmine, second)
}

///|
async test "live: a search finds the issues carrying a unique word" {
  guard relations_search_live_redmine() is Some(redmine) else { return }
  let nonce = @env.now().to_string()
  let first = create_probe_issue(redmine, "relsearch\{nonce}find")
  let second = create_probe_issue(redmine, "relsearch\{nonce}find")
  let found = redmine.search(
    { ..search_query("relsearch\{nonce}"), issues: Some(true), },
    limit=10,
  )
  assert_true(found.any(fn(r) { r.id == first && r.kind == "issue" }))
  assert_true(found.any(fn(r) { r.id == second }))
  delete_probe_issue(redmine, first)
  delete_probe_issue(redmine, second)
}
