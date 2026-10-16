///|
test "parse splits origin and base path" {
  let plain = Endpoint::parse("http://localhost:3000").unwrap()
  inspect(plain.origin, content="http://localhost:3000")
  inspect(plain.base_path, content="")
  let nested = Endpoint::parse("https://example.com/redmine/").unwrap()
  inspect(nested.origin, content="https://example.com")
  inspect(nested.base_path, content="/redmine")
  let upper = Endpoint::parse("HTTPS://example.com").unwrap()
  inspect(upper.origin, content="https://example.com")
}

///|
test "parse rejects unusable endpoints" {
  for
    endpoint in [
      "ftp://example.com", "example.com", "http://", "https:///redmine", "https://user:pass@example.com",
      "https://example.com?x=1", "https://example.com/redmine#top",
    ] {
    assert_true(Endpoint::parse(endpoint) is None)
  }
}

///|
test "path appends encoded segments to the base path" {
  let plain = Endpoint::parse("https://example.com").unwrap()
  inspect(plain.path(["projects", "1.json"]), content="/projects/1.json")
  inspect(plain.path([]), content="/")
  let nested = Endpoint::parse("https://example.com/redmine").unwrap()
  inspect(
    nested.path(["projects", "1.json"]),
    content="/redmine/projects/1.json",
  )
  inspect(nested.path([]), content="/redmine")
  inspect(
    nested.path(["wiki", "a/b c", "日本語.json"]),
    content="/redmine/wiki/a%2Fb%20c/%E6%97%A5%E6%9C%AC%E8%AA%9E.json",
  )
}

///|
test "encode_query escapes reserved characters" {
  inspect(encode_query([]), content="")
  inspect(
    encode_query([("limit", "100"), ("offset", "0")]),
    content="limit=100&offset=0",
  )
  inspect(
    encode_query([
      ("created_on", "><2026-01-01|2026-01-31"),
      ("q", "a&b=c+d é"),
    ]),
    content="created_on=%3E%3C2026-01-01%7C2026-01-31&q=a%26b%3Dc%2Bd%20%C3%A9",
  )
}
