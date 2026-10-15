///|
/// A dual-era MCP server offering tools. Build one with `Server::new`.
pub struct Server {
  priv name : String
  priv version : String
  priv instructions : String?
  priv tools : Array[Tool]
  priv on_invalid : (@schema.SchemaError) -> ToolResult
  priv mut initialized : Bool
}

///|
/// Creates a server that identifies itself as `name` and `version` and offers
/// `tools` in the given order. `instructions` is guidance for the model, sent
/// to the client as is. `on_invalid` turns a failed argument validation into
/// the result the model sees; it defaults to the joined validation messages.
pub fn Server::new(
  name~ : String,
  version~ : String,
  tools~ : Array[Tool],
  instructions? : String,
  on_invalid~ : (@schema.SchemaError) -> ToolResult = default_on_invalid,
) -> Server {
  { name, version, instructions, tools, on_invalid, initialized: false, }
}

///|
fn Server::server_info(self : Server) -> Json {
  { "name": Json(self.name), "version": Json(self.version) }
}

///|
let capabilities : Json = { "tools": {} }

///|
fn Server::add_instructions(
  self : Server,
  fields : Array[(String, Json)],
) -> Unit {
  if self.instructions is Some(text) {
    fields.push(("instructions", Json(text)))
  }
}

///|
fn Server::result_for(
  self : Server,
  era : Era,
  fields : Array[(String, Json)],
) -> Json {
  match era {
    Legacy => Json::object(Map::from_array(fields))
    Modern =>
      Json::object(
        Map::from_array(
          [
            ("resultType", "complete"),
            ..fields,
            (
              "_meta",
              Json::object(
                Map::from_array([(server_info_key, self.server_info())]),
              ),
            ),
          ],
        ),
      )
  }
}
