///|
/// The keyring service every redmoon credential lives under; it differs from
/// denomine-mcp's so the two tools never read each other's keys.
pub const SERVICE : String = "redmoon"

///|
/// Where API keys are kept, addressed by canonical endpoint.
pub(open) trait CredentialStore {
  fn get(Self, account : String) -> String? raise CliError
  fn set(Self, account : String, secret : String) -> Unit raise CliError
  fn delete(Self, account : String) -> Unit raise CliError
  fn list(Self) -> Array[String] raise CliError
}

///|
/// The OS credential store, reached through `omochice/keyring`.
pub(all) struct OsKeyring {}

///|
/// macOS errSecInteractionNotAllowed: a keychain item is readable without a
/// prompt only by the executable that created it, so a rebuilt binary is
/// refused whenever no permission dialog can be shown (e.g. under `serve`).
const KEYCHAIN_INTERACTION_NOT_ALLOWED : Int32 = -25308

///|
fn refusal(code : Int32, account : String?) -> String {
  if code != KEYCHAIN_INTERACTION_NOT_ALLOWED {
    return "the credential store refused the operation (code \{code})"
  }
  let (subject, endpoint) = match account {
    Some(account) => ("the API key for \{account}", account)
    None => ("the stored API keys", "<endpoint>")
  }
  "the keychain did not let this redmoon executable read \{subject}, which happens after redmoon is rebuilt or upgraded; run `redmoon logout --endpoint \{endpoint}` and then `redmoon login --endpoint \{endpoint}`"
}

///|
fn describe(error : @keyring.KeyringError, account : String?) -> CliError {
  match error {
    NoStore(message) => Message(message)
    Refused(code) => Message(refusal(code, account))
  }
}

///|
pub impl CredentialStore for OsKeyring with fn get(_, account) {
  @keyring.get(SERVICE, account) catch {
    error => raise describe(error, Some(account))
  }
}

///|
pub impl CredentialStore for OsKeyring with fn set(_, account, secret) {
  @keyring.set(SERVICE, account, secret) catch {
    error => raise describe(error, Some(account))
  }
}

///|
pub impl CredentialStore for OsKeyring with fn delete(_, account) {
  @keyring.delete(SERVICE, account) catch {
    error => raise describe(error, Some(account))
  }
}

///|
pub impl CredentialStore for OsKeyring with fn list(_) {
  @keyring.list(SERVICE) catch {
    error => raise describe(error, None)
  }
}

///|
pub extend OsKeyring with CredentialStore::{get, set, delete, list}
