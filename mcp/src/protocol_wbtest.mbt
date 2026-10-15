///|
fn new_server() -> Server {
  Server::new(name="demo", version="1.2.3")
}

///|
fn send(server : Server, request : Json) -> String {
  match server.dispatch(request.stringify()) {
    Reply(json) => json.stringify()
    Nothing => ""
  }
}

///|
fn initialize_request(version : String) -> Json {
  {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": { "protocolVersion": version, "capabilities": {} },
  }
}

///|
test "initialize answers a requested legacy version with the same version" {
  for version in legacy_versions {
    assert_eq(
      send(new_server(), initialize_request(version)),
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"\{version}\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"demo\",\"version\":\"1.2.3\"}}}",
    )
  }
}

///|
test "initialize answers an unknown or modern version with 2025-11-25" {
  for version in ["1.0.0", "2026-07-28"] {
    assert_eq(
      send(new_server(), initialize_request(version)),
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"demo\",\"version\":\"1.2.3\"}}}",
    )
  }
}

///|
test "initialize carries instructions when configured" {
  let server = Server::new(name="demo", version="1", instructions="be kind")
  assert_eq(
    send(server, initialize_request("2025-06-18")),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"demo\",\"version\":\"1\"},\"instructions\":\"be kind\"}}",
  )
}

///|
test "initialize without a protocolVersion is invalid params" {
  assert_eq(
    send(new_server(), {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {},
    }),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32602,\"message\":\"`protocolVersion` is required\"}}",
  )
}

///|
test "notifications get no answer" {
  let server = new_server()
  assert_eq(
    send(server, { "jsonrpc": "2.0", "method": "notifications/initialized" }),
    "",
  )
  assert_eq(send(server, { "jsonrpc": "2.0", "method": "no/such" }), "")
}

///|
test "ping answers an empty result in every state" {
  let server = new_server()
  let ping : Json = { "jsonrpc": "2.0", "id": 5, "method": "ping" }
  assert_eq(send(server, ping), "{\"jsonrpc\":\"2.0\",\"id\":5,\"result\":{}}")
  ignore(send(server, initialize_request("2025-11-25")))
  assert_eq(send(server, ping), "{\"jsonrpc\":\"2.0\",\"id\":5,\"result\":{}}")
}

///|
test "an unknown method is -32601" {
  assert_eq(
    send(new_server(), { "jsonrpc": "2.0", "id": 9, "method": "resources/list" }),
    "{\"jsonrpc\":\"2.0\",\"id\":9,\"error\":{\"code\":-32601,\"message\":\"Method not found: resources/list\"}}",
  )
}

///|
test "malformed JSON is -32700 with a null id" {
  assert_eq(
    match new_server().dispatch("{nope") {
      Reply(json) =>
        json.stringify().contains("\"id\":null,\"error\":{\"code\":-32700")
      Nothing => false
    },
    true,
  )
}

///|
test "an invalid request is -32600" {
  assert_eq(
    match new_server().dispatch("{\"jsonrpc\":\"2.0\",\"id\":4}") {
      Reply(json) => json.stringify()
      Nothing => ""
    },
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"error\":{\"code\":-32600,\"message\":\"Invalid Request: `method` must be a string\"}}",
  )
}
