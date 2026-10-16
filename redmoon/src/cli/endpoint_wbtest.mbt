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
  for raw in ["not a url", "https://"] {
    try canonicalize_endpoint(raw) catch {
      Message(_) => ()
    } noraise {
      _ => fail("\{raw} was accepted")
    }
  }
}

///|
test "an endpoint with credentials is rejected without echoing them" {
  try canonicalize_endpoint("https://user:pw@r.example.com") catch {
    e =>
      inspect(
        e,
        content="credentials in the endpoint URL are not supported; enter the API key at the prompt",
      )
  } noraise {
    _ => fail("credentials were accepted")
  }
}

///|
test "an endpoint serve cannot use is rejected" {
  for raw in ["ftp://r.example.com", "file:///etc/passwd", "ws://host"] {
    try canonicalize_endpoint(raw) catch {
      Message(_) => ()
    } noraise {
      _ => fail("\{raw} was accepted")
    }
  }
}

///|
test "an accepted endpoint is accepted by the SDK" {
  for
    raw in [
      "https://R.Example.com/", "http://localhost:3000/?token=x#frag", "https://host/redmine/",
      "HTTPS://host:443/", "http://host:8080",
    ] {
    let canonical = canonicalize_endpoint(raw)
    ignore(@redmine.Redmine::new(endpoint=canonical, api_key="k"))
  }
}
