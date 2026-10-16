///|
/// An absolute http(s) URL split into the origin to connect to and the request target.
pub(all) struct Location {
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
pub fn normalize_origin(origin : String) -> String {
  guard origin.find("://") is Some(scheme_end) else { return origin }
  let scheme = origin[:scheme_end].to_lower().to_owned()
  let authority = origin[scheme_end + 3:].to_lower().to_owned()
  let suffix = ":" + default_port_of(scheme)
  match authority.strip_suffix(suffix) {
    Some(host) => "\{scheme}://\{host}"
    None => "\{scheme}://\{authority}"
  }
}

///|
pub fn same_origin(a : String, b : String) -> Bool {
  normalize_origin(a) == normalize_origin(b)
}

///|
/// Splits an absolute http(s) URL into origin and path-with-query, dropping the fragment.
pub fn parse_absolute_url(url : String) -> Location? {
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
pub fn resolve_location(current : Location, location : String) -> Location? {
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
pub fn is_redirect_status(status : Int32) -> Bool {
  status == 301 ||
  status == 302 ||
  status == 303 ||
  status == 307 ||
  status == 308
}
