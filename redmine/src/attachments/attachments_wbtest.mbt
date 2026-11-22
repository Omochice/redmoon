///|
test "the first download request goes to the endpoint, not the reported host" {
  let redmine = @redmine.new(endpoint="https://r.example/redmine", api_key="k")
  let attachment : Attachment = {
    id: 1,
    filename: "a.txt",
    filesize: 3,
    content_type: Some("text/plain"),
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

///|
test "an attachment without a content type is decoded" {
  let json = @json.parse(
    (
      #|{"id":4,"filename":"README","filesize":5,"content_type":null,"content_url":"http://localhost:3000/attachments/download/4/README","author":{"id":1,"name":"Redmine Admin"},"created_on":"2026-10-16T01:02:03Z"}
    ),
  )
  let attachment : Attachment = @decode.decode(@wire.strip_nulls(json))
  assert_eq(attachment.content_type, None)
}

///|
test "an attachment larger than 2 GiB is decoded and encoded as a number" {
  let text =
    #|{"id":5,"filename":"big.iso","filesize":3000000000,"content_url":"http://localhost:3000/attachments/download/5/big.iso","author":{"id":1,"name":"Redmine Admin"},"created_on":"2026-10-16T01:02:03Z"}
  let attachment : Attachment = @decode.decode(@json.parse(text))
  assert_eq(attachment.filesize.to_int64(), 3000000000L)
  assert_eq(attachment.to_json().stringify(), text)
}

///|
test "a filesize that is not a non-negative integer number is rejected" {
  for filesize in ["\"5\"", "1.5", "-1"] {
    let decoded : Result[ByteSize, _] = Ok(
      @json.from_json(@json.parse(filesize)),
    ) catch {
      e => Err(e)
    }
    assert_true(decoded is Err(_), msg="filesize \{filesize}")
  }
}

///|
let download_start : @wire.Location = {
  origin: "https://r.example",
  target: "/attachments/download/1/a.txt",
}

///|
async test "a redirect leads to the location its Location header names" {
  let next = next_location(download_start, 302, Some("/files/b.txt"), fn() {
    ""
  })
  guard next is Some(next) else { fail("the redirect was not followed") }
  assert_eq(next.origin, "https://r.example")
  assert_eq(next.target, "/files/b.txt")
}

///|
async test "a Location header on an answer that is not a redirect is not followed" {
  let ok = next_location(download_start, 200, Some("/elsewhere"), fn() { "" })
  assert_true(ok is None)
  try
    next_location(download_start, 300, Some("/elsewhere"), fn() { "" })
  catch {
    Response(status~, ..) => assert_eq(status, 300)
    _ => fail("expected a Response error")
  } noraise {
    _ => fail("a 300 answer was followed")
  }
}

///|
async test "a redirect to a URL that is not http(s) is refused" {
  for target in ["javascript:alert(1)", "ftp://cdn.example/a.txt"] {
    try next_location(download_start, 302, Some(target), fn() { "" }) catch {
      Transport(message~) =>
        assert_eq(message, "refused to follow a redirect to an unsupported URL")
      _ => fail("expected a Transport error for \{target}")
    } noraise {
      _ => fail("followed a redirect to \{target}")
    }
  }
}

///|
async test "a non-2xx answer raises the errors its body carries" {
  try
    next_location(download_start, 403, None, fn() {
      "{\"errors\":[\"You are not authorized\"]}"
    })
  catch {
    Response(status~, errors~) => {
      assert_eq(status, 403)
      assert_eq(errors, ["You are not authorized"])
    }
    _ => fail("expected a Response error")
  } noraise {
    _ => fail("a 403 answer was taken as a body")
  }
}

///|
async test "a successful answer leaves its body unread for the consumer" {
  let read = Ref(false)
  let next = next_location(download_start, 200, None, fn() {
    read.val = true
    ""
  })
  assert_true(next is None)
  assert_false(read.val)
}

///|
async test "a download requests each redirect target in turn until one answers with a body" {
  let requested = []
  follow_redirects(download_start, fn(location) {
    requested.push(location.target)
    match location.target {
      "/attachments/download/1/a.txt" => Some({ ..location, target: "/one", })
      "/one" => Some({ ..location, target: "/two", })
      _ => None
    }
  })
  assert_eq(requested, ["/attachments/download/1/a.txt", "/one", "/two"])
}

///|
async test "a download gives up once it has followed MAX_REDIRECTS redirects" {
  let mut requests = 0
  try
    follow_redirects(download_start, fn(location) {
      requests += 1
      Some(location)
    })
  catch {
    @redmine.Transport(message~) =>
      assert_eq(message, "attachment download followed more than 20 redirects")
    _ => fail("expected a Transport error")
  } noraise {
    _ => fail("an endless redirect was followed to the end")
  }
  assert_eq(requests, MAX_REDIRECTS + 1)
}
