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
  let current : Location = {
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
  assert_eq(resolve("b.txt").unwrap().target, "/attachments/download/1/b.txt")
  assert_eq(
    resolve("../2/b.txt").unwrap().target,
    "/attachments/download/2/b.txt",
  )
  assert_eq(
    resolve("?q=2").unwrap().target,
    "/attachments/download/1/a.txt?q=2",
  )
  assert_true(resolve("ftp://h/x") is None)
  assert_true(resolve("javascript:alert(1)") is None)
}

///|
test "same_origin strips only the default port, not trailing digits of the host" {
  assert_true(same_origin("https://10.0.0.34:443", "https://10.0.0.34"))
  assert_true(same_origin("http://10.0.0.80:80", "http://10.0.0.80"))
  assert_false(same_origin("http://10.0.0.80:80", "http://10.0.0.8:80"))
  assert_eq(normalize_origin("https://10.0.0.34:443"), "https://10.0.0.34")
}
