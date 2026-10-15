///|
/// A dual-era MCP server offering tools. Build one with `Server::new`.
pub struct Server {
  priv name : String
  priv version : String
  priv instructions : String?
  priv mut negotiated : String?
}

///|
/// Creates a server that identifies itself as `name` and `version`;
/// `instructions` is guidance for the model, sent to the client as is.
pub fn Server::new(
  name~ : String,
  version~ : String,
  instructions? : String,
) -> Server {
  { name, version, instructions, negotiated: None, }
}

///|
fn Server::server_info(self : Server) -> Json {
  object([("name", Json(self.name)), ("version", Json(self.version))])
}

///|
fn Server::capabilities(_ : Server) -> Json {
  object([("tools", object([]))])
}

///|
fn Server::result_for(
  self : Server,
  era : Era,
  fields : Array[(String, Json)],
) -> Json {
  match era {
    Legacy => object(fields)
    Modern =>
      object(
        [
          ("resultType", "complete"),
          ..fields,
          ("_meta", object([(server_info_key, self.server_info())])),
        ],
      )
  }
}
