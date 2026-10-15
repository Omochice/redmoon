///|
test "wiki page segments sanitize the title and select the version" {
  assert_eq(wiki_page_segments(Identifier("demo"), "My Page.v2/x"), [
    "projects", "demo", "wiki", "My_Page_v2_x.json",
  ])
  assert_eq(wiki_page_segments(Id(1), "Home", version=3), [
    "projects", "1", "wiki", "Home", "3.json",
  ])
}

///|
test "wiki page body leaves unset fields out" {
  assert_eq(
    wiki_page_body("hello").stringify(),
    "{\"wiki_page\":{\"text\":\"hello\"}}",
  )
  assert_eq(
    wiki_page_body("hello", comments="why", version=2, parent_title="A B").stringify(),
    "{\"wiki_page\":{\"text\":\"hello\",\"comments\":\"why\",\"version\":2,\"parent_title\":\"A_B\"}}",
  )
}

///|
test "wiki page summaries decode a Redmine index" {
  let json = @json.parse(
    (
      #|{"wiki_pages":[{"title":"Home","version":3,"project":{"id":1,"name":"Demo"},"created_on":"2026-10-15T18:06:44Z","updated_on":"2026-10-15T18:06:44Z","parent":{"title":"Root"}},{"title":"Root","version":1,"created_on":"2026-10-15T18:06:44Z","updated_on":"2026-10-15T18:06:44Z"}]}
    ),
  )
  let pages : Array[WikiPageSummary] = decode_field(json, "wiki_pages") catch {
    _ => fail("decode")
  }
  assert_eq(pages.length(), 2)
  assert_eq(pages[0].parent, Some({ title: "Root", }))
  assert_eq(pages[1].parent, None)
}

///|
test "a wiki page decodes with and without comments" {
  let json = @json.parse(
    (
      #|{"wiki_page":{"title":"Home","text":"hello","version":1,"author":{"id":1,"name":"Redmine Admin"},"comments":null,"project":{"id":1,"name":"Demo"},"created_on":"2026-10-15T18:06:44Z","updated_on":"2026-10-15T18:06:44Z"}}
    ),
  )
  let page : WikiPage = decode_field(strip_nulls(json), "wiki_page") catch {
    _ => fail("decode")
  }
  assert_eq(page.comments, None)
  assert_eq(page.author, { id: 1, name: "Redmine Admin", })
  assert_eq(page.attachments, None)
}
