///|
/// What the transport has to do about one incoming line.
priv enum Action {
  Reply(Json)
  Call(id~ : Json, tool~ : Tool, arguments~ : Json, era~ : Era)
  Cancel(request_id~ : Json)
  Nothing
}

///|
fn Server::dispatch(self : Server, line : String) -> Action {
  match parse_message(line) {
    Unparseable(reason) =>
      Reply(
        error_response(
          Json::null(),
          RpcError::new(parse_error_code, "Parse error: \{reason}"),
        ),
      )
    Malformed(id~, reason~) =>
      Reply(
        error_response(
          id,
          RpcError::new(invalid_request_code, "Invalid Request: \{reason}"),
        ),
      )
    Response => Nothing
    Notification(name~, params~) =>
      match (name, params.get("requestId")) {
        (
          "notifications/cancelled",
          Some(String(_) as id)
          | Some(Number(_) as id),
        ) => Cancel(request_id=id)
        _ => Nothing
      }
    Request(id~, name~, params~) => self.route(id, name, params)
  }
}

///|
fn Server::route(
  self : Server,
  id : Json,
  name : String,
  params : Map[String, Json],
) -> Action {
  let outcome = match name {
    "initialize" => self.initialize(params)
    "ping" => self.ping(params)
    "server/discover" => self.discover(params)
    "tools/list" => self.list_tools(params)
    "tools/call" =>
      match self.plan_call(params) {
        Ok((tool, arguments, era)) => return Call(id~, tool~, arguments~, era~)
        Err(error) => Err(error)
      }
    _ => Err(RpcError::new(method_not_found_code, "Method not found: \{name}"))
  }
  match outcome {
    Ok(result) => Reply(result_response(id, result))
    Err(error) => Reply(error_response(id, error))
  }
}

///|
/// Runs the tool of a planned call. The only await in the protocol, so the
/// transport can keep reading while a handler waits.
async fn Server::respond(
  self : Server,
  id~ : Json,
  tool~ : Tool,
  arguments~ : Json,
  era~ : Era,
) -> Json {
  let result = (tool.invoke)(arguments, self.on_invalid)
  result_response(id, self.result_for(era, result.to_fields()))
}

///|
fn Server::initialize(
  self : Server,
  params : Map[String, Json],
) -> Result[Json, RpcError] {
  guard params.get("protocolVersion") is Some(String(requested)) else {
    return Err(invalid_params("`protocolVersion` is required"))
  }
  let negotiated = if legacy_versions.contains(requested) {
    requested
  } else {
    fallback_legacy_version
  }
  self.initialized = true
  let fields : Array[(String, Json)] = [
    ("protocolVersion", Json(negotiated)),
    ("capabilities", capabilities),
    ("serverInfo", self.server_info()),
  ]
  self.add_instructions(fields)
  Ok(Json::object(Map::from_array(fields)))
}

///|
fn Server::ping(
  self : Server,
  params : Map[String, Json],
) -> Result[Json, RpcError] {
  match resolve_era(params, self.initialized) {
    Ok(era) => Ok(self.result_for(era, []))
    Err({ code, .. } as error) if code == unsupported_version_code => Err(error)
    Err(_) => Ok({})
  }
}

///|
fn Server::discover(
  self : Server,
  params : Map[String, Json],
) -> Result[Json, RpcError] {
  match resolve_era(params, self.initialized) {
    Err(error) => Err(error)
    Ok(Legacy) =>
      Err(
        RpcError::new(
          method_not_found_code, "Method not found: server/discover",
        ),
      )
    Ok(Modern) => {
      let fields : Array[(String, Json)] = [
        (
          "supportedVersions",
          Json::array(supported_versions().map(v => Json(v))),
        ),
        ("capabilities", capabilities),
      ]
      self.add_instructions(fields)
      Ok(self.result_for(Modern, fields))
    }
  }
}

///|
fn Server::list_tools(
  self : Server,
  params : Map[String, Json],
) -> Result[Json, RpcError] {
  match resolve_era(params, self.initialized) {
    Err(error) => Err(error)
    Ok(era) =>
      Ok(
        self.result_for(era, [
          ("tools", Json::array(self.tools.map(t => t.to_json()))),
        ]),
      )
  }
}

///|
fn Server::plan_call(
  self : Server,
  params : Map[String, Json],
) -> Result[(Tool, Json, Era), RpcError] {
  let era = match resolve_era(params, self.initialized) {
    Err(error) => return Err(error)
    Ok(era) => era
  }
  guard params.get("name") is Some(String(name)) else {
    return Err(invalid_params("`name` is required"))
  }
  let arguments = match params.get("arguments") {
    None | Some(Null) => Json::object({})
    Some(Object(_) as arguments) => arguments
    Some(_) => return Err(invalid_params("`arguments` must be an object"))
  }
  for tool in self.tools {
    if tool.name == name {
      return Ok((tool, arguments, era))
    }
  }
  Err(invalid_params("Unknown tool: \{name}"))
}
