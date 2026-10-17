///|
test "wiki page segments convert the title and select the version" {
  assert_eq(
    page_segments(@redmine.ProjectRef::Identifier("demo"), "My Page.v2/x"),
    ["projects", "demo", "wiki", "My_Pagev2x.json"],
  )
  assert_eq(page_segments(@redmine.ProjectRef::Id(1), "Home", version=3), [
    "projects", "1", "wiki", "Home", "3.json",
  ])
}

///|
test "wiki page body leaves unset fields out" {
  assert_eq(
    page_body("hello").stringify(),
    "{\"wiki_page\":{\"text\":\"hello\"}}",
  )
  assert_eq(
    page_body("hello", comments="why", version=2, parent_title="A B").stringify(),
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
  let pages : Array[PageSummary] = @decode.decode_field(json, "wiki_pages") catch {
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
  let page : Page = @decode.decode_field(@wire.strip_nulls(json), "wiki_page") catch {
    _ => fail("decode")
  }
  assert_eq(page.comments, None)
  assert_eq(page.author, { id: 1, name: "Redmine Admin", })
  assert_eq(page.attachments, None)
}

///|
test "wiki titles are converted the way Redmine's titleize does" {
  assert_eq(wiki_title_segment("Release v1.0"), "Release_v10")
  assert_eq(wiki_title_segment("a  b"), "a_b")
  assert_eq(wiki_title_segment("a \t\nb"), "a_b")
  assert_eq(wiki_title_segment("x,y"), "xy")
  assert_eq(wiki_title_segment("a/b?c;d|e:f"), "abcdef")
}

///|
test "wiki page body converts parent_title like a page title" {
  let body = page_body("t", parent_title="Release v1.0")
  assert_eq(
    body.stringify(),
    "{\"wiki_page\":{\"text\":\"t\",\"parent_title\":\"Release_v10\"}}",
  )
}

///|
test "the attachments of a wiki page carry the full metadata" {
  let json = @json.parse(
    (
      #|{"wiki_page":{"title":"Home","text":"hello","version":1,"author":{"id":1,"name":"Redmine Admin"},"comments":null,"created_on":"2026-10-15T18:06:44Z","updated_on":"2026-10-15T18:06:44Z","attachments":[{"id":4,"filename":"f.txt","filesize":12,"content_type":"text/plain","description":"","content_url":"http://localhost:3000/attachments/download/4/f.txt","author":{"id":1,"name":"Redmine Admin"},"created_on":"2026-10-15T18:06:44Z"}]}}
    ),
  )
  let page : Page = @decode.decode_field(@wire.strip_nulls(json), "wiki_page") catch {
    _ => fail("decode")
  }
  let attachment = page.attachments.unwrap()[0]
  assert_eq(attachment.filesize, 12)
  assert_eq(attachment.content_type, Some("text/plain"))
  assert_eq(attachment.author, { id: 1, name: "Redmine Admin", })
}
