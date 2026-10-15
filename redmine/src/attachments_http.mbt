///|
/// The Fetch standard's own limit; redirects are followed by hand only to keep
/// the API key from crossing origins.
const MAX_REDIRECTS : Int32 = 20

///|
priv struct AttachmentLocation {
  origin : String
  /// Path and query, starting with `/`.
  target : String
}

///|
fn default_port_of(scheme : String) -> String {
  if scheme == "https" {
    "443"
  } else {
    "80"
  }
}

///|
/// Lowercases scheme and host and drops the scheme's default port, so that
/// spellings of one origin compare equal as they do for the URL standard.
fn normalize_origin(origin : String) -> String {
  guard origin.find("://") is Some(scheme_end) else { return origin }
  let scheme = origin[:scheme_end].to_lower().to_owned()
  let authority = origin[scheme_end + 3:].to_lower().to_owned()
  let suffix = ":" + default_port_of(scheme)
  if authority.has_suffix(suffix) {
    "\{scheme}://\{authority.trim_end(chars=suffix)}"
  } else {
    "\{scheme}://\{authority}"
  }
}

///|
fn same_origin(a : String, b : String) -> Bool {
  normalize_origin(a) == normalize_origin(b)
}

///|
/// Splits an absolute http(s) URL into origin and path-with-query, dropping the fragment.
fn parse_absolute_url(url : String) -> AttachmentLocation? {
  guard url.find("://") is Some(scheme_end) else { return None }
  let scheme = url[:scheme_end].to_lower().to_owned()
  guard scheme == "http" || scheme == "https" else { return None }
  let rest = url[scheme_end + 3:]
  let rest = match rest.find("#") {
    Some(i) => rest[:i]
    None => rest
  }
  let authority_end = rest
    .find_by(c => c == '/' || c == '?')
    .unwrap_or(rest.length())
  let authority = rest[:authority_end]
  guard authority != "" && !authority.contains("@") else { return None }
  let tail = rest[authority_end:].to_owned()
  let target = if tail.has_prefix("/") { tail } else { "/\{tail}" }
  Some({ origin: "\{scheme}://\{authority}", target, })
}

///|
fn remove_dot_segments(path : String) -> String {
  let output : Array[String] = []
  let segments = path.split("/").collect()
  for i, segment in segments {
    let segment = segment.to_owned()
    match segment {
      "." => if i == segments.length() - 1 { output.push("") }
      ".." => {
        if output.length() > 1 {
          let _ = output.pop()
        }
        if i == segments.length() - 1 {
          output.push("")
        }
      }
      _ => output.push(segment)
    }
  }
  output.join("/")
}

///|
/// Resolves a `Location` header against the URL that answered with it.
/// Returns `None` for anything other than an http(s) URL.
fn resolve_location(
  current : AttachmentLocation,
  location : String,
) -> AttachmentLocation? {
  let scheme = current.origin[:current.origin.find("://").unwrap()].to_owned()
  if location.has_prefix("//") {
    return parse_absolute_url("\{scheme}:\{location}")
  }
  let is_absolute = match location.find(":") {
    Some(colon) => !location[:colon].contains_any(chars="/?#") && colon > 0
    None => false
  }
  if is_absolute {
    return parse_absolute_url(location)
  }
  let location = match location.find("#") {
    Some(i) => location[:i].to_owned()
    None => location
  }
  let (path, query) = match location.find("?") {
    Some(i) => (location[:i].to_owned(), location[i:].to_owned())
    None => (location, "")
  }
  let current_path = match current.target.find("?") {
    Some(i) => current.target[:i].to_owned()
    None => current.target
  }
  let resolved = if location == "" {
    current.target
  } else if path.has_prefix("/") {
    remove_dot_segments(path) + query
  } else if path == "" {
    current_path + query
  } else {
    let slash = current_path.rev_find("/").unwrap()
    remove_dot_segments(current_path[:slash + 1].to_owned() + path) + query
  }
  Some({ origin: current.origin, target: resolved, })
}

///|
fn is_redirect_status(status : Int32) -> Bool {
  status == 301 ||
  status == 302 ||
  status == 303 ||
  status == 307 ||
  status == 308
}

///|
/// The first request goes to the configured endpoint, not to the host `content_url`
/// names: behind a misconfigured reverse proxy Redmine reports its own idea of
/// scheme and host, which can be plain http even when it was reached over https.
fn Redmine::attachment_content_location(
  self : Redmine,
  attachment : Attachment,
) -> AttachmentLocation raise RedmineError {
  guard parse_absolute_url(attachment.content_url) is Some(content) else {
    raise Transport(message="attachment has an invalid `content_url`")
  }
  { origin: self.endpoint.origin, target: content.target, }
}

///|
/// Requests `location` on `client`. Returns the next location when the answer is
/// a redirect, and `None` when the body of a successful answer is ready to be read.
async fn attachment_fetch(
  client : @http.Client,
  location : AttachmentLocation,
) -> AttachmentLocation? raise RedmineError {
  let response = try {
    client.request(Get, location.target)
    client.end_request()
  } catch {
    error => raise Transport(message="\{error}")
  }
  let redirect = if is_redirect_status(response.code) {
    response.headers.get("Location")
  } else {
    None
  }
  if redirect is Some(target) {
    guard resolve_location(location, target) is Some(next) else {
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
    raise Response(status=response.code, errors=errors_from_body(text))
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
  client.request(Post, "\{path}?\{encode_query([("filename", filename)])}", extra_headers={
    "Content-Type": "application/octet-stream",
    "Content-Length": size.to_string(),
  })
  client.write_reader(body)
  let response = client.end_request()
  (response.code, client.read_all().text())
}
