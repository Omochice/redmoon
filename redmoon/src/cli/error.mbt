///|
/// Raised by every CLI operation; the message is shown to the user as is.
pub suberror CliError {
  Message(String)
}

///|
pub impl Show for CliError with fn output(self, logger) {
  match self {
    Message(message) => logger.write_string(message)
  }
}

///|
pub extend CliError with Show::{to_string, output}
