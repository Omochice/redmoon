///|
/// The parsed form of the endpoint a client talks to.
pub(all) struct Endpoint {
  /// `scheme://host[:port]`
  origin : String
  /// Empty, or starts with `/` and has no trailing `/`.
  base_path : String
}

///|
/// Splits an endpoint into its origin and base path.
/// Returns `None` for anything but `http(s)://host[:port][/path]`; the endpoint
/// is not echoed anywhere because it may carry credentials.
pub fn Endpoint::parse(endpoint : String) -> Endpoint? {
  guard endpoint.find("://") is Some(scheme_end) else { return None }
  let scheme = endpoint[:scheme_end].to_lower().to_owned()
  guard scheme == "http" || scheme == "https" else { return None }
  let rest = endpoint[scheme_end + 3:]
  let (authority, path) = match rest.find("/") {
    Some(slash) => (rest[:slash], rest[slash:])
    None => (rest, "")
  }
  guard authority != "" &&
    !authority.contains_any(chars="@?#") &&
    !path.contains_any(chars="?#") else {
    return None
  }
  Some({
    origin: "\{scheme}://\{authority}",
    base_path: path.trim_end(chars="/").to_owned(),
  })
}

///|
/// Builds a request path by appending percent-encoded segments to the base path.
pub fn Endpoint::path(self : Endpoint, segments : Array[String]) -> String {
  let builder = StringBuilder()
  builder.write_string(self.base_path)
  for segment in segments {
    builder.write_char('/')
    builder.write_string(@percent.encode(segment))
  }
  if segments.is_empty() && self.base_path == "" {
    builder.write_char('/')
  }
  builder.to_string()
}

///|
/// Builds `key=value&...` with both sides percent-encoded; empty for no pairs.
pub fn encode_query(pairs : Array[(String, String)]) -> String {
  pairs
  .map(fn(pair) { "\{@percent.encode(pair.0)}=\{@percent.encode(pair.1)}" })
  .join("&")
}
