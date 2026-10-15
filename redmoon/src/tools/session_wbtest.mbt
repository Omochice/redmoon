///|
/// What a model receives from one `tools/call`.
struct Called {
  text : String
  is_error : Bool
}

///|
async fn run_session(
  server : @mcp.Server,
  client : async (&@io.Writer) -> Unit,
) -> String {
  let (in_read, in_write) = @io.pipe()
  let (out_read, out_write) = @io.pipe()
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      defer out_write.close()
      server.serve(in_read, out_write)
    })
    let collected = group.spawn(async fn() { out_read.read_all().text() })
    {
      defer in_write.close()
      client(in_write)
    }
    collected.wait()
  })
}

///|
fn new_server(tools : Array[@mcp.Tool]) -> @mcp.Server {
  @mcp.Server::new(name="redmoon-test", version="0.0.0", tools~, on_invalid~)
}

///|
fn request_line(id : Int32, rpc_method : String, params : Json) -> String {
  let request : Json = {
    "jsonrpc": "2.0",
    "id": id,
    "method": rpc_method,
    "params": params,
  }
  request.stringify() + "\n"
}

///|
fn initialize_line() -> String {
  request_line(1, "initialize", {
    "protocolVersion": "2025-11-25",
    "capabilities": {},
  })
}

///|
/// The `result` of the second response line, i.e. the answer to `rpc_method`.
async fn ask(
  tools : Array[@mcp.Tool],
  rpc_method : String,
  params : Json,
) -> Json {
  let output = run_session(new_server(tools), async fn(w) {
    w.write(initialize_line())
    w.write(request_line(2, rpc_method, params))
  })
  let lines = output.split("\n").collect()
  guard @json.parse(lines[1].to_owned()) is { "result": result, .. } else {
    fail("no result in \{output}")
  }
  result
}

///|
async fn call_tool(
  tools : Array[@mcp.Tool],
  name : String,
  arguments : Json,
) -> Called {
  let result = ask(tools, "tools/call", { "name": name, "arguments": arguments })
  guard result
    is {
      "content": [{ "text": String(text), .. }, ..],
      "isError": is_error,
      ..
    } else {
    fail("unexpected result \{result.stringify()}")
  }
  { text, is_error: is_error is True, }
}

///|
async fn list_tools(tools : Array[@mcp.Tool]) -> Json {
  ask(tools, "tools/list", {})
}

///|
fn text_of(result : @mcp.ToolResult) -> String {
  guard result.content is [Text(text)] else {
    abort("expected one text content")
  }
  text
}
