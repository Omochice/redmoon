///|
/// What the SDK needs to talk to one Redmine: the parsed endpoint and the API key.
/// The fields are private so that only the free functions below can read the key.
pub struct Connection {
  priv endpoint : @wire.Endpoint
  priv api_key : String
}

///|
/// Parses `endpoint`; `None` when it is not an http(s) URL.
pub fn connect(endpoint : String, api_key : String) -> Connection? {
  guard @wire.Endpoint::parse(endpoint) is Some(endpoint) else { return None }
  Some({ endpoint, api_key, })
}

///|
/// The `scheme://host[:port]` the connection talks to.
pub fn origin(conn : Connection) -> String {
  conn.endpoint.origin
}

///|
/// Opens a client for `origin`.
/// The API key is attached only when `origin` is the endpoint's own, because a download may be
/// redirected to a third party. The caller closes the client.
pub async fn open_client(
  conn : Connection,
  origin : String,
  accept? : String,
) -> @http.Client {
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  if @wire.same_origin(origin, conn.endpoint.origin) {
    headers["X-Redmine-API-Key"] = conn.api_key
  }
  if accept is Some(accept) {
    headers["Accept"] = accept
  }
  @http.Client(origin, headers~)
}

///|
/// Opens a JSON API client for the endpoint together with the request target of `segments`
/// and `query`, so that every call to the API names its resource the same way.
/// The caller closes the client.
pub async fn open_api(
  conn : Connection,
  segments : Array[String],
  query~ : Array[(String, String)] = [],
) -> (@http.Client, String) {
  let client = open_client(
    conn,
    conn.endpoint.origin,
    accept="application/json",
  )
  let path = conn.endpoint.path(segments)
  let target = if query.is_empty() {
    path
  } else {
    "\{path}?\{@wire.encode_query(query)}"
  }
  (client, target)
}

///|
/// A finished exchange, classified without choosing how failures are reported.
/// The root package owns `RedmineError`, which consumers match on, so this package cannot raise it.
pub enum Interpretation {
  Body(Json)
  Rejected(status~ : Int32, errors~ : Array[String])
  Malformed(message~ : String)
}

///|
/// Classifies a status and body: a 2xx answer yields its JSON with `null` members removed,
/// `null` for an empty body.
pub fn interpret(status : Int32, text : String) -> Interpretation {
  guard status >= 200 && status < 300 else {
    return Rejected(status~, errors=@wire.errors_from_body(text))
  }
  guard text != "" else { return Body(Json::null()) }
  let json = @json.parse(text) catch {
    error => return Malformed(message="invalid JSON in response: \{error}")
  }
  Body(@wire.strip_nulls(json))
}
