///|
/// A wiki index as a fake `list` sees it, recording every tag it was asked for.
priv struct FakeWikiIndex {
  pages : Array[@wiki.PageSummary]
  requested : Array[String]
  ignores_tag : Bool
}

///|
fn FakeWikiIndex::new(ignores_tag~ : Bool = false) -> FakeWikiIndex {
  let pages : Array[@wiki.PageSummary] = [
    {
      title: "Guide",
      version: 1,
      created_on: "2026-11-01T00:00:00Z",
      updated_on: "2026-11-02T00:00:00Z",
      parent: None,
    },
  ]
  { pages, requested: [], ignores_tag, }
}

///|
async fn FakeWikiIndex::search(
  self : FakeWikiIndex,
  name : String,
) -> Array[@wiki.PageSummary] raise @redmine.RedmineError {
  search_wiki_pages(name, list=tag => {
    self.requested.push(tag)
    if self.ignores_tag || tag == "howto" {
      self.pages
    } else {
      []
    }
  })
}

///|
async test "the probe is listed before the search, and the search answers its pages" {
  let index = FakeWikiIndex::new()
  let pages = index.search(" howto ")
  assert_eq(pages.map(page => page.title), ["Guide"])
  assert_eq(index.requested, [NO_TAG_CAN_MATCH, "howto"])
}

///|
async test "an index that answers the probe is reported as ignoring the tag" {
  let index = FakeWikiIndex::new(ignores_tag=true)
  try index.search("howto") catch {
    Decode(message~) => assert_eq(message, WIKI_TAGS_IGNORED)
    error => fail(message_of(error))
  } noraise {
    _ => fail("an ignored tag must not be reported as a match")
  }
  assert_eq(index.requested, [NO_TAG_CAN_MATCH])
}

///|
async test "a blank name or a name with a comma is refused before any listing" {
  let cases : Array[(String, String)] = [
    ("  ", "a tag name must not be empty or only spaces"),
    (
      "a,b", "the tag name `a,b` contains a comma, which the plugin would split into several tags",
    ),
  ]
  for entry in cases {
    let index = FakeWikiIndex::new()
    try index.search(entry.0) catch {
      Transport(message~) => assert_eq(message, entry.1)
      error => fail(message_of(error))
    } noraise {
      _ => fail("expected \{entry.1}")
    }
    assert_eq(index.requested, [])
  }
}

///|
test "the probe holds a comma, so no tag the plugin stores can match it" {
  assert_true(NO_TAG_CAN_MATCH.contains_char(','))
}
