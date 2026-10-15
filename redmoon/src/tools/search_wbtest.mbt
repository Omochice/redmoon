///|
struct FakeSearch {
  failure : @redmine.RedmineError?
  queries : Array[@redmine.SearchQuery]
}

///|
fn FakeSearch::check(self : FakeSearch) -> Unit raise @redmine.RedmineError {
  if self.failure is Some(error) {
    raise error
  }
}

///|
impl SearchPort for FakeSearch with fn search(self, query) {
  self.queries.push(query)
  self.check()
  [
    {
      id: 5,
      title: "login fails",
      kind: "issue",
      url: "https://redmine.example/issues/5",
      description: Some("Cannot log in"),
      datetime: "2026-01-02T03:04:05Z",
    },
    {
      id: 6,
      title: "login guide",
      kind: "wiki-page",
      url: "https://redmine.example/wiki/login",
      description: None,
      datetime: "2026-01-03T03:04:05Z",
    },
  ]
}

///|
fn fake_search(failure? : @redmine.RedmineError) -> FakeSearch {
  FakeSearch::{ failure, queries: [], }
}

///|
fn plain_query(q : String) -> @redmine.SearchQuery {
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
async test "search forwards the query and answers each match with Redmine's keys" {
  let fake = fake_search()
  let called = call_tool([search_tool(fake)], "redmine_search", {
    "search": { "q": "login" },
  })
  assert_eq(called.is_error, false)
  assert_eq(fake.queries, [plain_query("login")])
  assert_eq(
    called.text,
    "[{\"id\":5,\"title\":\"login fails\",\"type\":\"issue\",\"url\":\"https://redmine.example/issues/5\",\"description\":\"Cannot log in\",\"datetime\":\"2026-01-02T03:04:05Z\"},{\"id\":6,\"title\":\"login guide\",\"type\":\"wiki-page\",\"url\":\"https://redmine.example/wiki/login\",\"description\":null,\"datetime\":\"2026-01-03T03:04:05Z\"}]",
  )
}

///|
async test "every flag and the scope reach the query" {
  let fake = fake_search()
  let _ = call_tool([search_tool(fake)], "redmine_search", {
    "search": {
      "q": "login",
      "scope": "all",
      "all_words": true,
      "titles_only": false,
      "open_issues": true,
      "issues": true,
      "news": false,
      "documents": false,
      "changesets": false,
      "wiki_pages": true,
      "messages": false,
      "projects": false,
      "attachments": "only",
    },
  })
  assert_eq(fake.queries, [
    {
      q: "login",
      scope: Some("all"),
      all_words: Some(true),
      titles_only: Some(false),
      open_issues: Some(true),
      issues: Some(true),
      news: Some(false),
      documents: Some(false),
      changesets: Some(false),
      wiki_pages: Some(true),
      messages: Some(false),
      projects: Some(false),
      attachments: Some(Only),
    },
  ])
}

///|
async test "attachments true and false map to Included and Excluded" {
  let fake = fake_search()
  let tools = [search_tool(fake)]
  let _ = call_tool(tools, "redmine_search", {
    "search": { "q": "a", "attachments": true },
  })
  let _ = call_tool(tools, "redmine_search", {
    "search": { "q": "a", "attachments": false },
  })
  assert_eq(fake.queries[0].attachments, Some(Included))
  assert_eq(fake.queries[1].attachments, Some(Excluded))
}

///|
async test "an attachments string other than only is rejected naming the field" {
  let called = call_tool([search_tool(fake_search())], "redmine_search", {
    "search": { "q": "a", "attachments": "yes" },
  })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: search.attachments: no alternative matched: expected a boolean; must be `only`\"]}",
  )
}

///|
async test "a missing q is reported with its action path" {
  let called = call_tool([search_tool(fake_search())], "redmine_search", {
    "search": {},
  })
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: search.q: is required\"]}",
  )
}

///|
async test "a camelCase flag is rejected as an unknown field" {
  let called = call_tool([search_tool(fake_search())], "redmine_search", {
    "search": { "q": "a", "allWords": true },
  })
  assert_eq(
    called.text,
    "{\"status\":0,\"errors\":[\"invalid arguments: search.allWords: unknown field\"]}",
  )
}

///|
async test "a Redmine failure becomes a failure payload" {
  let called = call_tool(
    [
      search_tool(
        fake_search(failure=Response(status=422, errors=["q is invalid"])),
      ),
    ],
    "redmine_search",
    { "search": { "q": "a" } },
  )
  assert_eq(called.is_error, true)
  assert_eq(called.text, "{\"status\":422,\"errors\":[\"q is invalid\"]}")
}

///|
async test "tools/list advertises the search schema" {
  let advertised = list_tools(
    build_tools([always(search_tool(fake_search()))], Full),
  ).stringify()
  assert_eq(
    advertised, "{\"tools\":[{\"name\":\"redmine_search\",\"description\":\"Full-text search across Redmine issues, wiki pages, news, documents, changesets, messages, and projects.\\nRequires `q`; narrow with `scope` and the per-resource flags.\\nPass the arguments under the single key `search`: `{\\\"search\\\": {\\\"q\\\": \\\"login\\\"}}`.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"search\":{\"type\":\"object\",\"properties\":{\"q\":{\"type\":\"string\"},\"scope\":{\"type\":\"string\"},\"all_words\":{\"type\":\"boolean\"},\"titles_only\":{\"type\":\"boolean\"},\"open_issues\":{\"type\":\"boolean\"},\"issues\":{\"type\":\"boolean\"},\"news\":{\"type\":\"boolean\"},\"documents\":{\"type\":\"boolean\"},\"changesets\":{\"type\":\"boolean\"},\"wiki_pages\":{\"type\":\"boolean\"},\"messages\":{\"type\":\"boolean\"},\"projects\":{\"type\":\"boolean\"},\"attachments\":{\"anyOf\":[{\"type\":\"boolean\"},{\"type\":\"string\",\"const\":\"only\"}]}},\"required\":[\"q\"],\"additionalProperties\":false}},\"minProperties\":1,\"maxProperties\":1,\"additionalProperties\":false}}]}",
  )
}

///|
async test "live: a search finds an issue created for the test" {
  guard @env.get_env_var("REDMOON_TEST_ENDPOINT") is Some(endpoint) else {
    return
  }
  guard @env.get_env_var("REDMOON_TEST_API_KEY") is Some(api_key) else {
    return
  }
  let redmine = @redmine.Redmine::new(endpoint~, api_key~)
  let subject = "redmoon-search-\{@env.now()}"
  let created = redmine.create_issue(
    @redmine.IssueCreate::new(
      project_id=1,
      tracker_id=1,
      status_id=1,
      priority_id=2,
      subject~,
    ),
  )
  let outcome : Error? = try {
    let called = call_tool([search_tool(redmine)], "redmine_search", {
      "search": { "q": subject, "issues": true },
    })
    assert_eq(called.is_error, false)
    assert_true(called.text.contains(subject))
    None
  } catch {
    error => Some(error)
  }
  redmine.delete_issue(created.id)
  if outcome is Some(error) {
    raise error
  }
}
