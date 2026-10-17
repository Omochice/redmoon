///|
/// A client for one Redmine instance.
/// Each resource package takes it as the first argument of its functions, so
/// operations read as a pipeline: `redmine |> @issues.show(42)`.
pub struct Redmine {
  priv connection : @core.Connection
}

///|
const INVALID_ENDPOINT : String = "endpoint must be http(s)://host[:port][/path]"

///|
/// Creates a client for the Redmine at `endpoint`, e.g. `https://example.com/redmine`.
/// Raises `Transport` when `endpoint` is not an http(s) URL; the endpoint is not echoed in the message.
///
/// ```mbt check
/// test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com/redmine",
///     api_key="...",
///   )
///   ignore(redmine)
///   try @redmine.new(endpoint="ftp://redmine.example.com", api_key="...") catch {
///     Transport(..) => ()
///     error => fail(error.to_json().stringify())
///   } noraise {
///     _ => fail("an endpoint that is not http(s) must be rejected")
///   }
/// }
/// ```
pub fn new(endpoint~ : String, api_key~ : String) -> Redmine raise RedmineError {
  guard @core.connect(endpoint, api_key) is Some(connection) else {
    raise Transport(message=INVALID_ENDPOINT)
  }
  { connection, }
}

///|
/// Low-level escape hatch for endpoints the resource packages do not cover yet.
/// Sends one request and returns the response body as JSON, `null` when it is empty.
/// `segments` are appended to the endpoint's path and percent-encoded, and `null` members are removed from the answer.
/// Raises `Response` on a non-2xx answer and `Transport` on any other failure.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let projects = redmine
///     |> @redmine.send(Get, ["projects.json"], query=[("limit", "5")])
///   ignore(projects)
///   let created = redmine
///     |> @redmine.send(Post, ["projects.json"], body={
///       "project": { "name": "Demo", "identifier": "demo" },
///     })
///   ignore(created)
/// }
/// ```
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
  unwrap(@core.interpret(status, text))
}

///|
/// Turns a classified exchange into its JSON body, raising the matching `RedmineError` otherwise.
/// Public only so that the resource packages report failures the way `send` does; its
/// parameter type lives in an internal package, so nothing outside the SDK can call it.
pub fn unwrap(interpretation : @core.Interpretation) -> Json raise RedmineError {
  match interpretation {
    Body(json) => json
    Rejected(status~, errors~) => raise Response(status~, errors~)
    Malformed(message~) => raise Transport(message~)
  }
}

///|
/// The connection behind this client, for the SDK's own resource packages.
/// Its type lives in an internal package, so nothing can be done with the result outside them.
pub fn connection(redmine : Redmine) -> @core.Connection {
  redmine.connection
}

///|
async fn Redmine::exchange(
  self : Redmine,
  meth : @http.RequestMethod,
  segments : Array[String],
  query : Array[(String, String)],
  body : Json?,
) -> (Int32, String) {
  let conn = self.connection
  let client = @core.open_client(
    conn,
    @core.origin(conn),
    accept="application/json",
  )
  defer client.close()
  let path = @core.request_path(conn, segments)
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
