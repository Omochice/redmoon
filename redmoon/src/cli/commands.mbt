///|
/// Stores the API key read by `read_secret` for `endpoint` and returns the
/// account it was stored under.
///
/// # Raises
/// `Message` for an invalid endpoint, a key that cannot be read or is empty,
/// or a failing store.
pub async fn run_login(
  endpoint : String,
  store : &KeyringPort,
  read_secret : async () -> String,
) -> String raise CliError {
  let account = canonicalize_endpoint(endpoint)
  let secret = (read_secret() catch { error => raise Message("\{error}") })
    .trim()
    .to_owned()
  if secret == "" {
    raise Message("no API key was provided")
  }
  store.set(account~, secret~)
  account
}

///|
/// Removes the stored API key for `endpoint` and returns its account.
///
/// # Raises
/// `Message` for an invalid endpoint or a failing store.
pub fn run_logout(
  endpoint : String,
  store : &KeyringPort,
) -> String raise CliError {
  let account = canonicalize_endpoint(endpoint)
  store.delete(account~)
  account
}

///|
/// Returns the endpoints that have a stored API key, sorted for stable output.
///
/// # Raises
/// `Message` for a failing store.
pub fn run_list(store : &KeyringPort) -> Array[String] raise CliError {
  let endpoints = store.list()
  endpoints.sort()
  endpoints
}

///|
/// An endpoint paired with the API key stored for it.
pub(all) struct Credential {
  /// The canonical endpoint, which is also the keyring account.
  endpoint : String
  /// The Redmine API key stored for `endpoint`.
  api_key : String
}

///|
/// Looks up the API key for `endpoint`.
///
/// # Raises
/// `Message` telling the user to run `redmoon login` when no key is stored.
pub fn resolve_api_key(
  endpoint : String,
  store : &KeyringPort,
) -> Credential raise CliError {
  let account = canonicalize_endpoint(endpoint)
  match store.get(account~) {
    Some(api_key) => { endpoint: account, api_key, }
    None =>
      raise Message(
        "no stored API key for \{account}; run `redmoon login --endpoint \{account}` first",
      )
  }
}

///|
/// Serves the MCP protocol on stdin and stdout for the Redmine at `endpoint`.
/// Nothing else may write to stdout, because it is the protocol channel.
///
/// # Raises
/// `Message` when no API key is stored for `endpoint`, the endpoint is not an
/// http(s) URL, or the server fails while serving.
pub async fn run_serve(
  endpoint : String,
  read_only : Bool,
  plugins : Array[Plugin],
  store : &KeyringPort,
) -> Unit raise CliError {
  let credential = resolve_api_key(endpoint, store)
  let redmine = @redmine.new(
    endpoint=credential.endpoint,
    api_key=credential.api_key,
  ) catch {
    _ => raise Message("invalid endpoint URL: \{credential.endpoint}")
  }
  build_server(redmine, read_only, plugins).serve_stdio() catch {
    error => raise Message("\{error}")
  }
}
