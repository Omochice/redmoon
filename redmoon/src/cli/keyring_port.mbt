///|
/// Where API keys are kept, addressed by canonical endpoint.
pub(open) trait KeyringPort {
  /// The API key stored for `account`, or `None` when there is none.
  fn get(Self, account~ : String) -> String? raise CliError
  /// Stores `secret` for `account`, replacing any existing one.
  fn set(Self, account~ : String, secret~ : String) -> Unit raise CliError
  /// Removes the API key for `account`; an absent one is not an error.
  fn delete(Self, account~ : String) -> Unit raise CliError
  /// The accounts that hold an API key, in no particular order.
  fn list(Self) -> Array[String] raise CliError
}
