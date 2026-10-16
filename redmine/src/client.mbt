///|
/// A client for one Redmine instance.
pub struct Redmine {
  priv endpoint : @wire.Endpoint
  priv api_key : String
}

///|
const INVALID_ENDPOINT : String = "endpoint must be http(s)://host[:port][/path]"

///|
/// Creates a client for the Redmine at `endpoint`, e.g. `https://example.com/redmine`.
/// Raises `Transport` when `endpoint` is not an http(s) URL.
pub fn Redmine::new(
  endpoint~ : String,
  api_key~ : String,
) -> Redmine raise RedmineError {
  guard @wire.Endpoint::parse(endpoint) is Some(endpoint) else {
    raise Transport(message=INVALID_ENDPOINT)
  }
  { endpoint, api_key, }
}

///|
async fn Redmine::get(
  self : Redmine,
  segments : Array[String],
  query? : Array[(String, String)],
) -> Json raise RedmineError {
  self.send(Get, segments, query?)
}

///|
async fn Redmine::send(
  self : Redmine,
  meth : @http.RequestMethod,
  segments : Array[String],
  query~ : Array[(String, String)] = [],
  body? : Json,
) -> Json raise RedmineError {
  let (status, text) = self.exchange(meth, segments, query, body) catch {
    error => raise Transport(message="\{error}")
  }
  interpret_response(status, text)
}

///|
/// Turns a finished exchange into its JSON body, `null` when the body is empty.
fn interpret_response(status : Int32, text : String) -> Json raise RedmineError {
  guard status >= 200 && status < 300 else {
    raise Response(status~, errors=@wire.errors_from_body(text))
  }
  guard text != "" else { return Json::null() }
  let json = @json.parse(text) catch {
    error => raise Transport(message="invalid JSON in response: \{error}")
  }
  @wire.strip_nulls(json)
}

///|
/// Opens a connection to `origin`. The API key goes only to the endpoint's own
/// origin, because attachment downloads may be redirected to a third party.
async fn Redmine::open_client(
  self : Redmine,
  origin : String,
  accept? : String,
) -> @http.Client {
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  if @wire.same_origin(origin, self.endpoint.origin) {
    headers["X-Redmine-API-Key"] = self.api_key
  }
  if accept is Some(accept) {
    headers["Accept"] = accept
  }
  @http.Client(origin, headers~)
}

///|
async fn Redmine::exchange(
  self : Redmine,
  meth : @http.RequestMethod,
  segments : Array[String],
  query : Array[(String, String)],
  body : Json?,
) -> (Int32, String) {
  let client = self.open_client(self.endpoint.origin, accept="application/json")
  defer client.close()
  let path = self.endpoint.path(segments)
  let target = if query.is_empty() {
    path
  } else {
    "\{path}?\{@wire.encode_query(query)}"
  }
  match body {
    Some(json) => {
      let data = @utf8.encode(json.stringify())
      client.request(meth, target, extra_headers={
        "Content-Type": "application/json",
        "Content-Length": data.length().to_string(),
      })
      client.write(data)
    }
    None => client.request(meth, target)
  }
  let response = client.end_request()
  (response.code, client.read_all().text())
}

///|
fn[T : @json.FromJson] decode(json : Json) -> T raise RedmineError {
  @json.from_json(json) catch {
    error => raise Transport(message="unexpected response shape: \{error}")
  }
}

///|
/// Decodes `json[key]`, unwrapping Redmine's `{"<key>": ...}` envelope.
fn[T : @json.FromJson] decode_field(
  json : Json,
  key : String,
) -> T raise RedmineError {
  guard json is Object(members) && members.get(key) is Some(value) else {
    raise Transport(message="response has no `\{key}`")
  }
  decode(value)
}
