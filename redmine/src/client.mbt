///|
/// A client for one Redmine instance.
pub struct Redmine {
  priv endpoint : Endpoint
  priv api_key : String
}

///|
/// Creates a client for the Redmine at `endpoint`, e.g. `https://example.com/redmine`.
/// Raises `Transport` when `endpoint` is not an http(s) URL.
pub fn Redmine::new(
  endpoint~ : String,
  api_key~ : String,
) -> Redmine raise RedmineError {
  { endpoint: Endpoint::parse(endpoint), api_key, }
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
  guard status >= 200 && status < 300 else {
    raise Response(status~, errors=errors_from_body(text))
  }
  guard text != "" else { return Json::null() }
  let json = @json.parse(text) catch {
    error => raise Transport(message="invalid JSON in response: \{error}")
  }
  strip_nulls(json)
}

///|
async fn Redmine::exchange(
  self : Redmine,
  meth : @http.RequestMethod,
  segments : Array[String],
  query : Array[(String, String)],
  body : Json?,
) -> (Int32, String) {
  let client = @http.Client(self.endpoint.origin, headers={
    "X-Redmine-API-Key": self.api_key,
    "Accept": "application/json",
  })
  defer client.close()
  let path = self.endpoint.path(segments)
  let target = if query.is_empty() {
    path
  } else {
    "\{path}?\{encode_query(query)}"
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
