///|
test "same_origin ignores case and the default port" {
  assert_true(same_origin("HTTPS://Example.com:443", "https://example.com"))
  assert_true(same_origin("http://example.com:80", "http://example.com"))
  assert_false(same_origin("http://example.com", "https://example.com"))
  assert_false(same_origin("http://example.com:3000", "http://example.com"))
  assert_false(same_origin("https://example.com", "https://cdn.example.com"))
}

///|
test "parse_absolute_url splits the origin from path and query" {
  let url = parse_absolute_url("https://h.example:8443/a/b?x=1#frag").unwrap()
  assert_eq(url.origin, "https://h.example:8443")
  assert_eq(url.target, "/a/b?x=1")
  assert_eq(parse_absolute_url("https://h.example").unwrap().target, "/")
  assert_true(parse_absolute_url("ftp://h.example/a") is None)
  assert_true(parse_absolute_url("/relative") is None)
}

///|
test "resolve_location handles absolute, rooted and relative references" {
  let current : AttachmentLocation = {
    origin: "http://r.example",
    target: "/attachments/download/1/a.txt?k=v",
  }
  let resolve = fn(location) { resolve_location(current, location) }
  assert_eq(
    resolve("https://cdn.example/b?sig=1").unwrap().origin,
    "https://cdn.example",
  )
  assert_eq(resolve("//cdn.example/b").unwrap().origin, "http://cdn.example")
  assert_eq(resolve("/files/b.txt?z=1").unwrap().target, "/files/b.txt?z=1")
  assert_eq(
    resolve("b.txt").unwrap().target,
    "/attachments/download/1/b.txt",
  )
  assert_eq(resolve("../2/b.txt").unwrap().target, "/attachments/download/2/b.txt")
  assert_eq(resolve("?q=2").unwrap().target, "/attachments/download/1/a.txt?q=2")
  assert_true(resolve("ftp://h/x") is None)
  assert_true(resolve("javascript:alert(1)") is None)
}

///|
test "the first download request goes to the endpoint, not the reported host" {
  let redmine = Redmine::new(
    endpoint="https://r.example/redmine",
    api_key="k",
  )
  let attachment : Attachment = {
    id: 1,
    filename: "a.txt",
    filesize: 3,
    content_type: "text/plain",
    description: None,
    content_url: "http://internal:3000/attachments/download/1/a.txt",
    thumbnail_url: None,
    author: { id: 1, name: "Admin" },
    created_on: "2026-01-01T00:00:00Z",
  }
  let location = redmine.attachment_content_location(attachment)
  assert_eq(location.origin, "https://r.example")
  assert_eq(location.target, "/attachments/download/1/a.txt")
}

///|
test "an attachment response is decoded" {
  let json = @json.parse(
    (
      #|{"id":3,"filename":"a.txt","filesize":5,"content_type":"text/plain","description":"","content_url":"http://localhost:3000/attachments/download/3/a.txt","author":{"id":1,"name":"Redmine Admin"},"created_on":"2026-10-16T01:02:03Z"}
    ),
  )
  let attachment : Attachment = decode(json)
  assert_eq(attachment.filesize, 5)
  assert_eq(attachment.description, Some(""))
  assert_eq(attachment.thumbnail_url, None)
}
