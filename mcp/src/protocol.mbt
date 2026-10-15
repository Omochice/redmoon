///|
/// What the transport has to do about one incoming line.
priv enum Action {
  Reply(Json)
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
    Response | Notification(_) => Nothing
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
    _ => Err(RpcError::new(method_not_found_code, "Method not found: \{name}"))
  }
  match outcome {
    Ok(result) => Reply(result_response(id, result))
    Err(error) => Reply(error_response(id, error))
  }
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
  self.negotiated = Some(negotiated)
  let fields : Array[(String, Json)] = [
    ("protocolVersion", Json(negotiated)),
    ("capabilities", self.capabilities()),
    ("serverInfo", self.server_info()),
  ]
  if self.instructions is Some(text) {
    fields.push(("instructions", Json(text)))
  }
  Ok(object(fields))
}

///|
fn Server::ping(
  self : Server,
  params : Map[String, Json],
) -> Result[Json, RpcError] {
  match resolve_era(params, self.negotiated) {
    Ok(era) => Ok(self.result_for(era, []))
    Err({ code, .. } as error) if code == unsupported_version_code => Err(error)
    Err(_) => Ok(object([]))
  }
}
