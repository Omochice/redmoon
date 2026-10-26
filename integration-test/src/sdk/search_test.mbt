///|
fn query(q : String) -> @search.Query {
  {
    q,
    scope: None,
    all_words: None,
    titles_only: None,
    open_issues: None,
    issues: None,
    news: None,
    documents: None,
    changesets: None,
    wiki_pages: None,
    messages: None,
    projects: None,
    attachments: None,
  }
}

///|
async test "a search finds the issues carrying a unique word" {
  let redmine = @livetest.redmine()
  let nonce = @env.now().to_string()
  let first = @livetest.create_probe_issue(redmine, "searchprobe\{nonce}find")
  defer @livetest.delete_probe_issue(redmine, first)
  let second = @livetest.create_probe_issue(redmine, "searchprobe\{nonce}find")
  defer @livetest.delete_probe_issue(redmine, second)
  let found = redmine
    |> @search.search(
      { ..query("searchprobe\{nonce}"), issues: Some(true), },
      limit=10,
    )
  assert_true(found.any(fn(r) { r.id == first && r.kind == "issue" }))
  assert_true(found.any(fn(r) { r.id == second }))
}

///|
async test "a search returns the description of an issue that has one" {
  let redmine = @livetest.redmine()
  let nonce = @env.now().to_string()
  let id = @livetest.create_probe_issue(
    redmine,
    "descprobe\{nonce}",
    description="A search result with a description",
  )
  defer @livetest.delete_probe_issue(redmine, id)
  let found = redmine
    |> @search.search(
      { ..query("descprobe\{nonce}"), issues: Some(true), },
      limit=10,
    )
  guard found.search_by(fn(r) { r.id == id }) is Some(i) else {
    fail("the probe issue was not found")
  }
  assert_eq(found[i].description, Some("A search result with a description"))
}

///|
async test "all_words false matches issues carrying only one of the words" {
  let redmine = @livetest.redmine()
  let nonce = @env.now().to_string()
  let word_a = "allwa\{nonce}"
  let word_b = "allwb\{nonce}"
  let first = @livetest.create_probe_issue(redmine, word_a)
  let second = @livetest.create_probe_issue(redmine, word_b)
  defer @livetest.delete_probe_issue(redmine, first)
  defer @livetest.delete_probe_issue(redmine, second)
  let q = "\{word_a} \{word_b}"
  let any_word = redmine
    |> @search.search(
      { ..query(q), all_words: Some(false), issues: Some(true), },
      limit=10,
    )
  assert_true(any_word.any(fn(r) { r.id == first }))
  assert_true(any_word.any(fn(r) { r.id == second }))
  let every_word = redmine
    |> @search.search(
      { ..query(q), all_words: Some(true), issues: Some(true), },
      limit=10,
    )
  assert_false(every_word.any(fn(r) { r.id == first || r.id == second }))
}
