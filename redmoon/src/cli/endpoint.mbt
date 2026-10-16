///|
fn default_port(scheme : String) -> String? {
  match scheme {
    "http" => Some("80")
    "https" => Some("443")
    _ => None
  }
}

///|
/// Maps equivalent endpoint URLs to one keyring account: lower-case scheme and
/// host, no query, no fragment, no default port, no trailing slash.
///
/// # Raises
/// `Message` when `raw` carries credentials or is not an endpoint the SDK accepts.
pub fn canonicalize_endpoint(raw : String) -> String raise CliError {
  let invalid = Message("invalid endpoint URL: \{raw}")
  guard raw.find("://") is Some(scheme_end) else { raise invalid }
  let scheme = raw[:scheme_end].to_lower().to_owned()
  guard scheme != "" &&
    scheme
    .view()
    .iter()
    .all(c => c is ('a'..<='z' | '0'..<='9' | '+' | '-' | '.')) else {
    raise invalid
  }
  let rest = raw[scheme_end + 3:]
  let authority_end = rest
    .find_by(c => c is ('/' | '?' | '#'))
    .unwrap_or(rest.length())
  let authority = rest[:authority_end]
  let after_authority = rest[authority_end:]
  let path_end = after_authority
    .find_by(c => c is ('?' | '#'))
    .unwrap_or(after_authority.length())
  let path = after_authority[:path_end]
  let (userinfo, hostport) = match authority.rev_find("@") {
    Some(at) => (authority[:at + 1].to_owned(), authority[at + 1:])
    None => ("", authority)
  }
  guard userinfo == "" else {
    raise Message(
      "credentials in the endpoint URL are not supported; enter the API key at the prompt",
    )
  }
  guard hostport != "" else { raise invalid }
  let host = match hostport.rev_find(":") {
    Some(colon) if Some(hostport[colon + 1:].to_owned()) == default_port(scheme) =>
      hostport[:colon]
    _ => hostport
  }
  let canonical = "\{scheme}://\{host.to_lower()}\{path}"
  let canonical = canonical
    .strip_suffix("/")
    .map(StringView::to_owned)
    .unwrap_or(canonical)
  // Validity is delegated to the SDK rather than re-implemented, so that login
  // can never accept an endpoint that serve rejects.
  try ignore(@redmine.Redmine::new(endpoint=canonical, api_key="")) catch {
    _ => raise invalid
  } noraise {
    _ => ()
  }
  canonical
}
