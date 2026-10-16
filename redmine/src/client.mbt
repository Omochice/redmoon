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
  send(self, Get, segments, query?)
}

///|
/// Sends one request to the Redmine API and returns the response body as JSON, `null` when it is empty.
/// `segments` are appended to the endpoint's path and percent-encoded; `null` members are removed from the answer.
/// This is the escape hatch for endpoints the SDK has no function for; prefer the resource packages.
/// Raises `Response` on a non-2xx answer and `Transport` on any other failure.
pub async fn send(
  redmine : Redmine,
  meth : @http.RequestMethod,
  segments : Array[String],
  query~ : Array[(String, String)] = [],
  body? : Json,
) -> Json raise RedmineError {
  let (status, text) = redmine.exchange(meth, segments, query, body) catch {
    error => raise Transport(message="\{error}")
  }
  interpret_response(status, text)
}

///|
/// Turns a finished exchange into its JSON body, `null` when the body is empty.
/// Low level: it exists for requests made through `open_client`; `send` already applies it.
/// Raises `Response` on a non-2xx status and `Transport` when the body is not JSON.
pub fn interpret_response(
  status : Int32,
  text : String,
) -> Json raise RedmineError {
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
/// The `scheme://host[:port]` the client talks to.
/// Low level: it lets `open_client` callers build requests for the same server.
pub fn origin(redmine : Redmine) -> String {
  redmine.endpoint.origin
}

///|
/// The request path of `segments` below the endpoint's base path, percent-encoded.
/// Low level: `send` builds this itself.
pub fn request_path(redmine : Redmine, segments : Array[String]) -> String {
  redmine.endpoint.path(segments)
}

///|
/// Opens a connection to `origin` for a request `send` cannot express, such as a streamed body.
/// The API key is attached only when `origin` is the endpoint's own, because a download may be
/// redirected to a third party. The caller closes the client.
pub async fn open_client(
  redmine : Redmine,
  origin : String,
  accept? : String,
) -> @http.Client {
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  if @wire.same_origin(origin, redmine.endpoint.origin) {
    headers["X-Redmine-API-Key"] = redmine.api_key
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
  let client = open_client(
    self,
    self.endpoint.origin,
    accept="application/json",
  )
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
