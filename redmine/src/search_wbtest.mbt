///|
fn search_query(q : String) -> SearchQuery {
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
test "a bare search sends only the query" {
  assert_eq(search_query_pairs(search_query("login")), [("q", "login")])
}

///|
test "a true flag is sent as 1 and a false flag is left out" {
  let query = {
    ..search_query("login"),
    all_words: Some(true),
    titles_only: Some(false),
    issues: Some(true),
  }
  assert_eq(search_query_pairs(query), [
    ("q", "login"),
    ("all_words", "1"),
    ("issues", "1"),
  ])
}

///|
test "the scope and every type flag are sent under Redmine's names" {
  let query = {
    ..search_query("login"),
    scope: Some("my_projects"),
    open_issues: Some(true),
    news: Some(true),
    documents: Some(true),
    changesets: Some(true),
    wiki_pages: Some(true),
    messages: Some(true),
    projects: Some(true),
  }
  assert_eq(search_query_pairs(query), [
    ("q", "login"),
    ("scope", "my_projects"),
    ("open_issues", "1"),
    ("news", "1"),
    ("documents", "1"),
    ("changesets", "1"),
    ("wiki_pages", "1"),
    ("messages", "1"),
    ("projects", "1"),
  ])
}

///|
test "each attachment scope maps to its Redmine value" {
  assert_eq(
    search_query_pairs({ ..search_query("x"), attachments: Some(Excluded), }),
    [("q", "x"), ("attachments", "0")],
  )
  assert_eq(
    search_query_pairs({ ..search_query("x"), attachments: Some(Included), }),
    [("q", "x"), ("attachments", "1")],
  )
  assert_eq(
    search_query_pairs({ ..search_query("x"), attachments: Some(Only), }),
    [("q", "x"), ("attachments", "only")],
  )
}

///|
test "a result decodes from Redmine's response with a null description" {
  let text =
    #|{"results":[{"id":2,"title":"Bug #2 (New): login","type":"issue","url":"http://localhost:3000/issues/2","description":null,"datetime":"2026-10-15T18:08:53Z"}],"total_count":1,"offset":0,"limit":25}
  let json = @json.parse(text) catch { _ => fail("fixture is not JSON") }
  let results : Array[SearchResult] = decode_field(strip_nulls(json), "results") catch {
    _ => fail("results did not decode")
  }
  assert_eq(results.length(), 1)
  assert_eq(results[0].id, 2)
  assert_eq(results[0].kind, "issue")
  assert_eq(results[0].description, None)
  assert_eq(results[0].datetime, "2026-10-15T18:08:53Z")
}

///|
test "a missing total_count counts as no matches" {
  let json = @json.parse("{\"results\":[]}") catch {
    _ => fail("fixture is not JSON")
  }
  let total = total_count_of(strip_nulls(json)) catch {
    _ => fail("total_count did not decode")
  }
  assert_eq(total, 0)
}

///|
test "all_words false is sent as an empty value because Redmine defaults it to true" {
  let query = { ..search_query("login"), all_words: Some(false), }
  assert_eq(search_query_pairs(query), [("q", "login"), ("all_words", "")])
}
