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
fn describe(error : @keyring.KeyringError) -> CliError {
  match error {
    NoStore(message) => Message(message)
    Refused(code) =>
      Message("the credential store refused the operation (code \{code})")
  }
}

///|
pub impl CredentialStore for OsKeyring with fn get(_, account) {
  @keyring.get(SERVICE, account) catch {
    error => raise describe(error)
  }
}

///|
pub impl CredentialStore for OsKeyring with fn set(_, account, secret) {
  @keyring.set(SERVICE, account, secret) catch {
    error => raise describe(error)
  }
}

///|
pub impl CredentialStore for OsKeyring with fn delete(_, account) {
  @keyring.delete(SERVICE, account) catch {
    error => raise describe(error)
  }
}

///|
pub impl CredentialStore for OsKeyring with fn list(_) {
  @keyring.list(SERVICE) catch {
    error => raise describe(error)
  }
}

///|
pub extend OsKeyring with CredentialStore::{get, set, delete, list}
