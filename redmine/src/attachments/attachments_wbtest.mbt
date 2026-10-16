///|
test "the first download request goes to the endpoint, not the reported host" {
  let redmine = @redmine.Redmine::new(
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
    author: { id: 1, name: "Admin", },
    created_on: "2026-01-01T00:00:00Z",
  }
  let location = content_location(redmine, attachment)
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
  let attachment : Attachment = @decode.decode(json)
  assert_eq(attachment.filesize, 5)
  assert_eq(attachment.description, Some(""))
  assert_eq(attachment.thumbnail_url, None)
}
