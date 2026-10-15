///|
/// Stores the API key read by `read_secret` for `endpoint` and returns the
/// account it was stored under.
///
/// # Raises
/// `Message` for an invalid endpoint, an empty key, or a failing store.
pub async fn run_login(
  endpoint : String,
  store : &CredentialStore,
  read_secret : async () -> String,
) -> String {
  let account = canonicalize_endpoint(endpoint)
  let secret = read_secret().trim().to_owned()
  if secret == "" {
    raise Message("no API key was provided")
  }
  store.set(account, secret)
  account
}

///|
/// Removes the stored API key for `endpoint` and returns its account.
pub fn run_logout(
  endpoint : String,
  store : &CredentialStore,
) -> String raise CliError {
  let account = canonicalize_endpoint(endpoint)
  store.delete(account)
  account
}

///|
/// Returns the endpoints that have a stored API key, sorted for stable output.
pub fn run_list(store : &CredentialStore) -> Array[String] raise CliError {
  let endpoints = store.list()
  endpoints.sort()
  endpoints
}

///|
/// An endpoint paired with the API key stored for it.
pub(all) struct Credential {
  endpoint : String
  api_key : String
}

///|
/// Looks up the API key for `endpoint`.
///
/// # Raises
/// `Message` telling the user to run `login` when no key is stored.
pub fn resolve_api_key(
  endpoint : String,
  store : &CredentialStore,
) -> Credential raise CliError {
  let account = canonicalize_endpoint(endpoint)
  match store.get(account) {
    Some(api_key) => { endpoint: account, api_key, }
    None =>
      raise Message(
        "no stored API key for \{account}; run `login --endpoint \{account}` first",
      )
  }
}

///|
/// Serves the MCP protocol on stdin and stdout for the Redmine at `endpoint`.
/// Nothing else may write to stdout, because it is the protocol channel.
///
/// # Raises
/// `Message` when no API key is stored for `endpoint` or the endpoint is not an
/// http(s) URL.
pub async fn run_serve(
  endpoint : String,
  read_only : Bool,
  store : &CredentialStore,
) -> Unit {
  let credential = resolve_api_key(endpoint, store)
  let redmine = @redmine.Redmine::new(
    endpoint=credential.endpoint,
    api_key=credential.api_key,
  )
  build_server(redmine, read_only).serve_stdio()
}
