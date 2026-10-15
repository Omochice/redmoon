///|
/// A client message after framing and envelope checks, before any MCP meaning
/// is given to its method.
priv enum Message {
  Request(id~ : Json, name~ : String, params~ : Map[String, Json])
  Notification(name~ : String, params~ : Map[String, Json])
  Response
  Unparseable(String)
  Malformed(id~ : Json, reason~ : String)
}

///|
priv struct RpcError {
  code : Int32
  message : String
  data : Json?
}

///|
let parse_error_code : Int32 = -32700

///|
let invalid_request_code : Int32 = -32600

///|
let method_not_found_code : Int32 = -32601

///|
let invalid_params_code : Int32 = -32602

///|
let unsupported_version_code : Int32 = -32022

///|
fn RpcError::new(code : Int32, message : String, data? : Json) -> RpcError {
  { code, message, data, }
}

///|
fn object(entries : Array[(String, Json)]) -> Json {
  let fields : Map[String, Json] = Map([])
  for entry in entries {
    fields[entry.0] = entry.1
  }
  Json::object(fields)
}

///|
fn result_response(id : Json, result : Json) -> Json {
  object([("jsonrpc", "2.0"), ("id", id), ("result", result)])
}

///|
fn error_response(id : Json, error : RpcError) -> Json {
  let fields : Array[(String, Json)] = [
    ("code", Json(error.code)),
    ("message", Json(error.message)),
  ]
  if error.data is Some(data) {
    fields.push(("data", data))
  }
  object([("jsonrpc", "2.0"), ("id", id), ("error", object(fields))])
}

///|
fn parse_message(line : String) -> Message {
  let json = @json.parse(line) catch { err => return Unparseable("\{err}") }
  guard json is Object(fields) else {
    return Malformed(id=Json::null(), reason="a message must be a JSON object")
  }
  let id = fields.get("id")
  let usable_id = match id {
    Some(String(_) as i) | Some(Number(_) as i) => i
    _ => Json::null()
  }
  guard fields.get("jsonrpc") is Some(String("2.0")) else {
    return Malformed(id=usable_id, reason="`jsonrpc` must be \"2.0\"")
  }
  guard fields.get("method") is Some(String(name)) else {
    // A peer's response to a request this server never sent carries no method.
    return if fields.contains("result") || fields.contains("error") {
      Response
    } else {
      Malformed(id=usable_id, reason="`method` must be a string")
    }
  }
  let params = match fields.get("params") {
    None | Some(Null) => Map([])
    Some(Object(p)) => p
    Some(_) =>
      return Malformed(id=usable_id, reason="`params` must be an object")
  }
  match id {
    None => Notification(name~, params~)
    Some(String(_) as i) | Some(Number(_) as i) => Request(id=i, name~, params~)
    Some(_) =>
      Malformed(id=Json::null(), reason="`id` must be a string or a number")
  }
}
