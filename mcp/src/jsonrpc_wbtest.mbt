///|
fn show(message : Message) -> String {
  match message {
    Request(id~, name~, params~) =>
      "request \{id.stringify()} \{name} \{Json::object(params).stringify()}"
    Notification(name~, params~) =>
      "notification \{name} \{Json::object(params).stringify()}"
    Response => "reply"
    Unparseable(_) => "unparseable"
    Malformed(id~, reason~) => "malformed \{id.stringify()} \{reason}"
  }
}

///|
test "a request keeps its id and params" {
  assert_eq(
    show(
      parse_message(
        "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"ping\",\"params\":{\"a\":1}}",
      ),
    ),
    "request 7 ping {\"a\":1}",
  )
  assert_eq(
    show(
      parse_message("{\"jsonrpc\":\"2.0\",\"id\":\"x\",\"method\":\"ping\"}"),
    ),
    "request \"x\" ping {}",
  )
}

///|
test "a message without an id is a notification" {
  assert_eq(
    show(
      parse_message(
        "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}",
      ),
    ),
    "notification notifications/initialized {}",
  )
}

///|
test "malformed JSON is unparseable" {
  assert_eq(show(parse_message("{\"jsonrpc\"")), "unparseable")
}

///|
test "envelope violations are malformed requests carrying a usable id" {
  assert_eq(
    show(parse_message("[1]")),
    "malformed null a message must be a JSON object",
  )
  assert_eq(
    show(parse_message("{\"jsonrpc\":\"1.0\",\"id\":3,\"method\":\"ping\"}")),
    "malformed 3 `jsonrpc` must be \"2.0\"",
  )
  assert_eq(
    show(parse_message("{\"jsonrpc\":\"2.0\",\"id\":3}")),
    "malformed 3 `method` must be a string",
  )
  assert_eq(
    show(
      parse_message(
        "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"ping\",\"params\":[]}",
      ),
    ),
    "malformed 3 `params` must be an object",
  )
  assert_eq(
    show(parse_message("{\"jsonrpc\":\"2.0\",\"id\":null,\"method\":\"ping\"}")),
    "malformed null `id` must be a string or a number",
  )
}

///|
test "a response from the peer is ignored" {
  assert_eq(
    show(parse_message("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}")),
    "reply",
  )
}

///|
test "response builders" {
  assert_eq(
    result_response(Json(1), object([("a", Json(true))])).stringify(),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"a\":true}}",
  )
  assert_eq(
    error_response(Json::null(), RpcError::new(-32700, "bad")).stringify(),
    "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32700,\"message\":\"bad\"}}",
  )
  assert_eq(
    error_response(
      Json("a"),
      RpcError::new(-32022, "no", data=object([("k", Json(1))])),
    ).stringify(),
    "{\"jsonrpc\":\"2.0\",\"id\":\"a\",\"error\":{\"code\":-32022,\"message\":\"no\",\"data\":{\"k\":1}}}",
  )
}
