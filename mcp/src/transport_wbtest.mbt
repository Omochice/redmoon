///|
let slow_ms : Int32 = 150

///|
fn sleepy_tool() -> Tool {
  tool(
    name="sleepy",
    description="Waits, then answers",
    input=@schema.object(0) |> @schema.Obj::done,
    handler=async fn(_) {
      @async.sleep(slow_ms)
      ToolResult::text("done")
    },
  )
}

///|
fn forever_tool(started : Ref[Bool], finished : Ref[Bool]) -> Tool {
  tool(
    name="forever",
    description="Waits until cancelled",
    input=@schema.object(0) |> @schema.Obj::done,
    handler=async fn(_) {
      started.val = true
      @async.sleep(60000)
      finished.val = true
      ToolResult::text("never")
    },
  )
}

///|
fn line(json : Json) -> String {
  json.stringify() + "\n"
}

///|
fn legacy_call(id : Int32, name : String) -> Json {
  {
    "jsonrpc": "2.0",
    "id": id,
    "method": "tools/call",
    "params": { "name": name },
  }
}

///|
/// Runs `server` against an in-memory connection; `client` writes to the
/// server's input and the returned text is everything the server wrote.
async fn run_session(
  server : Server,
  client : async (&@io.Writer) -> Unit,
) -> String {
  let (in_read, in_write) = @io.pipe()
  let (out_read, out_write) = @io.pipe()
  @async.with_task_group(fn(group) {
    group.spawn_bg(fn() {
      defer out_write.close()
      server.serve(in_read, out_write)
    })
    let collected = group.spawn(fn() { out_read.read_all().text() })
    {
      defer in_write.close()
      client(in_write)
    }
    collected.wait()
  })
}

///|
async test "a session answers each line and ends at end of input" {
  let server = tools_server([greet_tool()])
  let output = run_session(server, async fn(w) {
    w.write(line(initialize_request("2025-11-25")))
    w.write(line({ "jsonrpc": "2.0", "method": "notifications/initialized" }))
    w.write(line({ "jsonrpc": "2.0", "id": 2, "method": "ping" }))
  })
  assert_eq(
    output, "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"demo\",\"version\":\"1.2.3\"}}}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}\n",
  )
}

///|
async test "blank lines are skipped and CRLF is tolerated" {
  let output = run_session(tools_server([]), async fn(w) {
    w.write("\n\r\n")
    w.write("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"ping\"}\r\n")
  })
  assert_eq(output, "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}\n")
}

///|
async test "garbage input is answered and the session continues" {
  let output = run_session(tools_server([]), async fn(w) {
    w.write("not json\n")
    w.write(line({ "jsonrpc": "2.0", "id": 2, "method": "ping" }))
  })
  let lines = output.split("\n").collect()
  assert_eq(lines[0].contains("\"id\":null,\"error\":{\"code\":-32700"), true)
  assert_eq(lines[1], "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}")
}

///|
async test "end of input waits for requests in flight" {
  let server = tools_server([sleepy_tool()])
  ignore(send(server, initialize_request("2025-11-25")))
  let output = run_session(server, async fn(w) {
    w.write(line(legacy_call(1, "sleepy")))
  })
  assert_eq(output.contains("\"text\":\"done\""), true)
}

///|
async test "a slow request does not block a later one" {
  let server = tools_server([sleepy_tool()])
  ignore(send(server, initialize_request("2025-11-25")))
  let output = run_session(server, async fn(w) {
    w.write(line(legacy_call(1, "sleepy")))
    w.write(line({ "jsonrpc": "2.0", "id": 2, "method": "ping" }))
  })
  let lines = output.split("\n").collect()
  assert_eq(lines[0], "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}")
  assert_eq(lines[1].contains("\"id\":1"), true)
}

///|
async test "cancelling a request stops its handler and suppresses its response" {
  let started = Ref(false)
  let finished = Ref(false)
  let server = tools_server([forever_tool(started, finished)])
  ignore(send(server, initialize_request("2025-11-25")))
  let output = run_session(server, async fn(w) {
    w.write(line(legacy_call(7, "forever")))
    @async.sleep(50)
    w.write(
      line({
        "jsonrpc": "2.0",
        "method": "notifications/cancelled",
        "params": { "requestId": 7 },
      }),
    )
    w.write(line({ "jsonrpc": "2.0", "id": 8, "method": "ping" }))
  })
  assert_eq(started.val, true)
  assert_eq(finished.val, false)
  assert_eq(output, "{\"jsonrpc\":\"2.0\",\"id\":8,\"result\":{}}\n")
}

///|
async test "cancelling an unknown or finished request is ignored" {
  let output = run_session(tools_server([]), async fn(w) {
    w.write(
      line({
        "jsonrpc": "2.0",
        "method": "notifications/cancelled",
        "params": { "requestId": 99 },
      }),
    )
    w.write(line({ "jsonrpc": "2.0", "method": "notifications/cancelled" }))
    w.write(line({ "jsonrpc": "2.0", "id": 8, "method": "ping" }))
  })
  assert_eq(output, "{\"jsonrpc\":\"2.0\",\"id\":8,\"result\":{}}\n")
}

///|
async test "a string request id is cancelled by a string requestId only" {
  let started = Ref(false)
  let finished = Ref(false)
  let server = tools_server([forever_tool(started, finished)])
  ignore(send(server, initialize_request("2025-11-25")))
  let output = run_session(server, async fn(w) {
    w.write(
      line({
        "jsonrpc": "2.0",
        "id": "a",
        "method": "tools/call",
        "params": { "name": "forever" },
      }),
    )
    @async.sleep(50)
    w.write(
      line({
        "jsonrpc": "2.0",
        "method": "notifications/cancelled",
        "params": { "requestId": "a" },
      }),
    )
  })
  assert_eq(output, "")
  assert_eq(finished.val, false)
}
