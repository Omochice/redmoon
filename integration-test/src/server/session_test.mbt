///|
/// What a model receives from one `tools/call`.
struct Called {
  text : String
  is_error : Bool
}

///|
/// The responses `server` writes, one per line, after an `initialize` followed by `requests`.
async fn exchange(server : @mcp.Server, requests : Array[Json]) -> Array[Json] {
  let (in_read, in_write) = @io.pipe()
  let (out_read, out_write) = @io.pipe()
  let output = @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      defer out_write.close()
      server.serve(in_read, out_write)
    })
    let collected = group.spawn(async fn() { out_read.read_all().text() })
    {
      defer in_write.close()
      let initialize : Json = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": { "protocolVersion": "2025-11-25", "capabilities": {} },
      }
      in_write.write(initialize.stringify() + "\n")
      for request in requests {
        in_write.write(request.stringify() + "\n")
      }
    }
    collected.wait()
  })
  let responses = []
  for line in output.split("\n") {
    if line.length() > 0 {
      responses.push(@json.parse(line.to_owned()))
    }
  }
  responses
}

///|
/// Calls the tool `name` through a whole MCP session with `server`, so that the arguments go through the same schema validation a model's call does.
async fn call(server : @mcp.Server, name : String, arguments : Json) -> Called {
  let responses = exchange(server, [
    {
      "jsonrpc": "2.0",
      "id": 2,
      "method": "tools/call",
      "params": { "name": name, "arguments": arguments },
    },
  ])
  guard responses
    is [
      _,
      {
        "result": {
          "content": [{ "text": String(text), .. }, ..],
          "isError": is_error,
          ..
        },
        ..
      },
      ..,
    ] else {
    fail("unexpected responses \{Json::array(responses).stringify()}")
  }
  { text, is_error: is_error is True, }
}

///|
async fn call_tool(
  tools : Array[@mcp.Tool],
  name : String,
  arguments : Json,
) -> Called {
  let server = @mcp.Server::new(
    name="redmoon-test",
    version="0.0.0",
    tools~,
    on_invalid=@tools.on_invalid,
  )
  call(server, name, arguments)
}
