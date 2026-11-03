///|
/// Where API keys are kept, addressed by canonical endpoint.
pub(open) trait KeyringPort {
  fn get(Self, account : String) -> String? raise CliError
  fn set(Self, account : String, secret : String) -> Unit raise CliError
  fn delete(Self, account : String) -> Unit raise CliError
  fn list(Self) -> Array[String] raise CliError
}
