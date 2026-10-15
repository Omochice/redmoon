///|
/// One piece of tool output. Only text is offered because redmoon returns JSON
/// documents as text.
pub(all) enum Content {
  Text(String)
}

///|
/// What a tool call returns to the model; `is_error` marks feedback the model
/// can use to correct its next call rather than a protocol failure.
pub(all) struct ToolResult {
  content : Array[Content]
  is_error : Bool
}

///|
/// A successful result holding `text`.
pub fn ToolResult::text(text : String) -> ToolResult {
  { content: [Text(text)], is_error: false, }
}

///|
/// A failed result holding `text`.
pub fn ToolResult::error(text : String) -> ToolResult {
  { content: [Text(text)], is_error: true, }
}

///|
/// A tool with its argument type erased, so tools of different argument types
/// share one array. Build one with `tool`.
pub struct Tool {
  priv name : String
  priv description : String
  priv input_schema : Json
  priv invoke : async (Json, (@schema.SchemaError) -> ToolResult) -> ToolResult
}

///|
/// Declares a tool whose arguments are parsed by `input` before `handler` runs.
/// Arguments that fail `input` never reach `handler`; the server answers them
/// with its invalid-arguments result instead. An error raised by `handler`
/// becomes an error result so one failing tool cannot take the server down.
pub fn[T] tool(
  name~ : String,
  description~ : String,
  input~ : @schema.Schema[T],
  handler~ : async (T) -> ToolResult,
) -> Tool {
  {
    name,
    description,
    input_schema: input.to_json_schema(),
    invoke: async fn(arguments, on_invalid) {
      let value = input.parse(arguments) catch { err => return on_invalid(err) }
      handler(value) catch {
        err => {
          if @async.is_being_cancelled() {
            raise err
          }
          ToolResult::error("\{err}")
        }
      }
    },
  }
}

///|
fn Tool::to_json(self : Tool) -> Json {
  {
    "name": Json(self.name),
    "description": Json(self.description),
    "inputSchema": self.input_schema,
  }
}

///|
fn ToolResult::to_fields(self : ToolResult) -> Array[(String, Json)] {
  let content : Array[Json] = self.content.map(c => {
    match c {
      Text(text) => { "type": "text", "text": Json(text) }
    }
  })
  [("content", Json::array(content)), ("isError", Json(self.is_error))]
}

///|
fn default_on_invalid(error : @schema.SchemaError) -> ToolResult {
  ToolResult::error(error.message())
}
