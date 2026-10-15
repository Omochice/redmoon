///|
test "equivalent endpoints map to one account" {
  inspect(
    canonicalize_endpoint("https://R.Example.com/"),
    content="https://r.example.com",
  )
  inspect(
    canonicalize_endpoint("https://r.example.com"),
    content="https://r.example.com",
  )
  inspect(
    canonicalize_endpoint("http://localhost:3000/?token=x#frag"),
    content="http://localhost:3000",
  )
  inspect(
    canonicalize_endpoint("https://host/redmine/"),
    content="https://host/redmine",
  )
}

///|
test "default ports and the scheme case are normalized" {
  inspect(canonicalize_endpoint("HTTPS://host:443/"), content="https://host")
  inspect(canonicalize_endpoint("http://host:8080"), content="http://host:8080")
}

///|
test "an unparseable endpoint is rejected" {
  assert_true((try? canonicalize_endpoint("not a url")) is Err(Message(_)))
  assert_true((try? canonicalize_endpoint("https://")) is Err(Message(_)))
}
