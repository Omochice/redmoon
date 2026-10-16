///|
fn new_server() -> Server {
  Server::new(name="demo", version="1.2.3", tools=[])
}

///|
fn reply_text(action : Action) -> String {
  match action {
    Reply(json) => json.stringify()
    _ => ""
  }
}

///|
fn send(server : Server, request : Json) -> String {
  reply_text(server.dispatch(request.stringify()))
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
  let server = Server::new(
    name="demo",
    version="1",
    tools=[],
    instructions="be kind",
  )
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
    reply_text(new_server().dispatch("{nope")).contains(
      "\"id\":null,\"error\":{\"code\":-32700",
    ),
    true,
  )
}

///|
test "an invalid request is -32600" {
  assert_eq(
    reply_text(new_server().dispatch("{\"jsonrpc\":\"2.0\",\"id\":4}")),
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"error\":{\"code\":-32600,\"message\":\"Invalid Request: `method` must be a string\"}}",
  )
}

///|
fn modern_meta(version~ : String = "2026-07-28") -> Json {
  {
    "io.modelcontextprotocol/protocolVersion": version,
    "io.modelcontextprotocol/clientCapabilities": {},
  }
}

///|
fn modern_request(
  name : String,
  params~ : Map[String, Json] = Map([]),
  version~ : String = "2026-07-28",
) -> Json {
  params["_meta"] = modern_meta(version~)
  { "jsonrpc": "2.0", "id": 1, "method": name, "params": Json::object(params) }
}

///|
test "server/discover answers versions, capabilities and identity" {
  assert_eq(
    send(new_server(), modern_request("server/discover")),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"resultType\":\"complete\",\"supportedVersions\":[\"2026-07-28\",\"2025-11-25\",\"2025-06-18\",\"2025-03-26\",\"2024-11-05\"],\"capabilities\":{\"tools\":{}},\"ttlMs\":3600000,\"cacheScope\":\"public\",\"_meta\":{\"io.modelcontextprotocol/serverInfo\":{\"name\":\"demo\",\"version\":\"1.2.3\"}}}}",
  )
}

///|
test "server/discover carries instructions" {
  let server = Server::new(
    name="demo",
    version="1",
    tools=[],
    instructions="be kind",
  )
  assert_eq(
    send(server, modern_request("server/discover")).contains(
      "\"instructions\":\"be kind\"",
    ),
    true,
  )
}

///|
test "a modern request needs no initialize" {
  let server = new_server()
  assert_eq(
    send(server, modern_request("ping")),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"resultType\":\"complete\",\"_meta\":{\"io.modelcontextprotocol/serverInfo\":{\"name\":\"demo\",\"version\":\"1.2.3\"}}}}",
  )
}

///|
test "a version outside the list is -32022 with supported and requested" {
  assert_eq(
    send(new_server(), modern_request("server/discover", version="1900-01-01")),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32022,\"message\":\"Unsupported protocol version\",\"data\":{\"supported\":[\"2026-07-28\",\"2025-11-25\",\"2025-06-18\",\"2025-03-26\",\"2024-11-05\"],\"requested\":\"1900-01-01\"}}}",
  )
}

///|
test "a modern request without clientCapabilities is -32602" {
  let request : Json = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "server/discover",
    "params": {
      "_meta": { "io.modelcontextprotocol/protocolVersion": "2026-07-28" },
    },
  }
  assert_eq(
    send(new_server(), request),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32602,\"message\":\"`_meta.io.modelcontextprotocol/clientCapabilities` is required\"}}",
  )
}

///|
test "a request with neither _meta version nor initialize is -32602" {
  assert_eq(
    send(new_server(), {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "server/discover",
    }),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32602,\"message\":\"`_meta.io.modelcontextprotocol/protocolVersion` is required before `initialize` has been called\"}}",
  )
}

///|
test "a non-string _meta version is -32602" {
  let request : Json = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "server/discover",
    "params": { "_meta": { "io.modelcontextprotocol/protocolVersion": 3 } },
  }
  assert_eq(
    send(new_server(), request),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32602,\"message\":\"`_meta.io.modelcontextprotocol/protocolVersion` must be a string\"}}",
  )
}

///|
test "server/discover is not offered to a legacy session" {
  let server = new_server()
  ignore(send(server, initialize_request("2025-11-25")))
  assert_eq(
    send(server, { "jsonrpc": "2.0", "id": 2, "method": "server/discover" }),
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"error\":{\"code\":-32601,\"message\":\"Method not found: server/discover\"}}",
  )
}

///|
test "a legacy version in _meta is served in the legacy shape" {
  assert_eq(
    send(new_server(), modern_request("ping", version="2025-11-25")),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}",
  )
}

///|
test "a modern request is served modern even after a legacy initialize" {
  let server = new_server()
  ignore(send(server, initialize_request("2025-11-25")))
  assert_eq(
    send(server, modern_request("ping")).contains("\"resultType\":\"complete\""),
    true,
  )
}

///|
test "ping with an unsupported version is -32022" {
  assert_eq(
    send(new_server(), modern_request("ping", version="1900-01-01")).contains(
      "-32022",
    ),
    true,
  )
}
