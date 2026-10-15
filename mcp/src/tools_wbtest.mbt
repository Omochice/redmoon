///|
struct Greeting {
  who : String
  times : Int32
}

///|
let greeting_schema : @schema.Schema[Greeting] = {
  let who = @schema.required("who", @schema.not_blank())
  let times = @schema.optional_or("times", @schema.integer(min=1), 1)
  @schema.record([who.as_member(), times.as_member()], v => {
    who: v.get(who),
    times: v.get(times),
  })
}

///|
fn greet_tool(handler? : async (Greeting) -> ToolResult) -> Tool {
  tool(
    name="greet",
    description="Greets someone",
    input=greeting_schema,
    handler=handler.unwrap_or(fn(g) {
      ToolResult::text(String::make(g.times, 'x') + " " + g.who)
    }),
  )
}

///|
fn tools_server(tools : Array[Tool]) -> Server {
  Server::new(name="demo", version="1.2.3", tools~)
}

///|
async fn call(server : Server, request : Json) -> String {
  match server.dispatch(request.stringify()) {
    Reply(json) => json.stringify()
    Call(id~, tool~, arguments~, era~) =>
      server.respond(id~, tool~, arguments~, era~).stringify()
    Cancel(_) | Nothing => ""
  }
}

///|
fn call_request(
  name : String,
  arguments : Json,
  meta~ : Json = Json::null(),
) -> Json {
  let params : Map[String, Json] = Map([])
  params["name"] = Json(name)
  params["arguments"] = arguments
  if meta is Object(_) {
    params["_meta"] = meta
  }
  {
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": Json::object(params),
  }
}

///|
test "tools/list in the legacy shape" {
  let server = tools_server([greet_tool()])
  ignore(send(server, initialize_request("2025-11-25")))
  assert_eq(
    send(server, { "jsonrpc": "2.0", "id": 3, "method": "tools/list" }),
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"tools\":[{\"name\":\"greet\",\"description\":\"Greets someone\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"who\":{\"type\":\"string\",\"pattern\":\"\\\\S\"},\"times\":{\"type\":\"integer\",\"minimum\":1,\"default\":1}},\"required\":[\"who\"],\"additionalProperties\":false}}]}}",
  )
}

///|
test "tools/list in the modern shape" {
  let server = tools_server([greet_tool()])
  assert_eq(
    send(server, modern_request("tools/list")),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"resultType\":\"complete\",\"tools\":[{\"name\":\"greet\",\"description\":\"Greets someone\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"who\":{\"type\":\"string\",\"pattern\":\"\\\\S\"},\"times\":{\"type\":\"integer\",\"minimum\":1,\"default\":1}},\"required\":[\"who\"],\"additionalProperties\":false}}],\"_meta\":{\"io.modelcontextprotocol/serverInfo\":{\"name\":\"demo\",\"version\":\"1.2.3\"}}}}",
  )
}

///|
test "tools/list keeps registration order" {
  let other = tool(
    name="alpha",
    description="",
    input=@schema.record([], _ => 0),
    handler=fn(_) { ToolResult::text("") },
  )
  let text = send(
    tools_server([greet_tool(), other]),
    modern_request("tools/list"),
  )
  assert_eq(
    text.find("\"greet\"").unwrap() < text.find("\"alpha\"").unwrap(),
    true,
  )
}

///|
test "tools/list before any version is -32602" {
  assert_eq(
    send(tools_server([greet_tool()]), {
      "jsonrpc": "2.0",
      "id": 3,
      "method": "tools/list",
    }).contains("-32602"),
    true,
  )
}

///|
async test "tools/call success, legacy" {
  let server = tools_server([greet_tool()])
  ignore(send(server, initialize_request("2025-11-25")))
  assert_eq(
    call(server, call_request("greet", { "who": "Bob", "times": 2 })),
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"xx Bob\"}],\"isError\":false}}",
  )
}

///|
async test "tools/call success, modern" {
  let server = tools_server([greet_tool()])
  assert_eq(
    call(server, call_request("greet", { "who": "Bob" }, meta=modern_meta())),
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"resultType\":\"complete\",\"content\":[{\"type\":\"text\",\"text\":\"x Bob\"}],\"isError\":false,\"_meta\":{\"io.modelcontextprotocol/serverInfo\":{\"name\":\"demo\",\"version\":\"1.2.3\"}}}}",
  )
}

///|
async test "invalid arguments become an error result with the messages" {
  let server = tools_server([greet_tool()])
  assert_eq(
    call(
      server,
      call_request("greet", { "who": " ", "extra": 1 }, meta=modern_meta()),
    ).contains("\"isError\":true"),
    true,
  )
  assert_eq(
    call(server, call_request("greet", { "who": " " }, meta=modern_meta())).contains(
      "who: must not be blank",
    ),
    true,
  )
}

///|
async test "the caller controls the text of an invalid-arguments result" {
  let server = Server::new(name="demo", version="1", tools=[greet_tool()], on_invalid=e => {
    ToolResult::error("custom: \{e.messages().length()}")
  })
  assert_eq(
    call(server, call_request("greet", { "who": 3 }, meta=modern_meta())).contains(
      "custom: 1",
    ),
    true,
  )
}

///|
async test "a handler failure becomes an error result" {
  let failing = greet_tool(handler=fn(_) raise { fail("backend down") })
  let server = tools_server([failing])
  let text = call(
    server,
    call_request("greet", { "who": "Bob" }, meta=modern_meta()),
  )
  assert_eq(text.contains("\"isError\":true"), true)
  assert_eq(text.contains("backend down"), true)
}

///|
async test "an unknown tool is -32602" {
  assert_eq(
    call(
      tools_server([greet_tool()]),
      call_request("nope", {}, meta=modern_meta()),
    ),
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"error\":{\"code\":-32602,\"message\":\"Unknown tool: nope\"}}",
  )
}

///|
async test "tools/call with a bad envelope is -32602" {
  let server = tools_server([greet_tool()])
  let no_name : Json = {
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": { "_meta": modern_meta() },
  }
  assert_eq(call(server, no_name).contains("`name` is required"), true)
  assert_eq(
    call(server, call_request("greet", [1], meta=modern_meta())).contains(
      "`arguments` must be an object",
    ),
    true,
  )
}

///|
async test "missing arguments are treated as an empty object" {
  let noargs = tool(
    name="now",
    description="",
    input=@schema.record([], _ => 0),
    handler=fn(_) { ToolResult::text("ok") },
  )
  let request : Json = {
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": { "name": "now", "_meta": modern_meta() },
  }
  assert_eq(
    call(tools_server([noargs]), request).contains("\"text\":\"ok\""),
    true,
  )
}
