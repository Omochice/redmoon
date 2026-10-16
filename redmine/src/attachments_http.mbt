///|
/// The Fetch standard's own limit; redirects are followed by hand only to keep
/// the API key from crossing origins.
const MAX_REDIRECTS : Int32 = 20

///|
/// The first request goes to the configured endpoint, not to the host `content_url`
/// names: behind a misconfigured reverse proxy Redmine reports its own idea of
/// scheme and host, which can be plain http even when it was reached over https.
fn Redmine::attachment_content_location(
  self : Redmine,
  attachment : Attachment,
) -> @wire.Location raise RedmineError {
  guard @wire.parse_absolute_url(attachment.content_url) is Some(content) else {
    raise Transport(message="attachment has an invalid `content_url`")
  }
  { origin: self.endpoint.origin, target: content.target, }
}

///|
/// Requests `location` on `client`. Returns the next location when the answer is
/// a redirect, and `None` when the body of a successful answer is ready to be read.
async fn attachment_fetch(
  client : @http.Client,
  location : @wire.Location,
) -> @wire.Location? raise RedmineError {
  let response = try {
    client.request(Get, location.target)
    client.end_request()
  } catch {
    error => raise Transport(message="\{error}")
  }
  let redirect = if @wire.is_redirect_status(response.code) {
    response.headers.get("Location")
  } else {
    None
  }
  if redirect is Some(target) {
    guard @wire.resolve_location(location, target) is Some(next) else {
      raise Transport(
        message="refused to follow a redirect to an unsupported URL",
      )
    }
    return Some(next)
  }
  guard response.code >= 200 && response.code < 300 else {
    let text = try {
      match client.read_some(max_len=ERROR_BODY_LIMIT) {
        Some(bytes) => @utf8.decode_lossy(bytes)
        None => ""
      }
    } catch {
      _ => ""
    }
    raise Response(status=response.code, errors=@wire.errors_from_body(text))
  }
  None
}

///|
const ERROR_BODY_LIMIT : Int32 = 65536

///|
async fn Redmine::attachment_post_upload(
  self : Redmine,
  body : &@io.Reader,
  size : Int64,
  filename : String,
) -> (Int32, String) {
  let client = self.open_client(self.endpoint.origin, accept="application/json")
  defer client.close()
  let path = self.endpoint.path(["uploads.json"])
  client.request(
    Post,
    "\{path}?\{@wire.encode_query([("filename", filename)])}",
    extra_headers={
      "Content-Type": "application/octet-stream",
      "Content-Length": size.to_string(),
    },
  )
  client.write_reader(body)
  let response = client.end_request()
  (response.code, client.read_all().text())
}
