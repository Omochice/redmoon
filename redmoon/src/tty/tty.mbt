///|
pub suberror TtyError {
  Message(String)
}

///|
pub extend TtyError with Show::{to_string, output}

///|
pub impl Show for TtyError with fn output(self, logger) {
  match self {
    Message(message) => logger.write_string(message)
  }
}

///|
extern "C" fn ffi_is_terminal() -> Int32 = "omochice_tty_is_terminal"

///|
#borrow(buf)
extern "C" fn ffi_read_secret(buf : FixedArray[Byte]) -> Int32 = "omochice_tty_read_secret"

///|
const MAX_SECRET_BYTES : Int32 = 4096

///|
fn read_hidden_line() -> String raise TtyError {
  let buf = FixedArray::make(MAX_SECRET_BYTES, b'\x00')
  let len = ffi_read_secret(buf)
  if len < 0 {
    raise Message(
      if len == -2 {
        "the input is longer than \{MAX_SECRET_BYTES} bytes"
      } else {
        "could not read from the terminal"
      },
    )
  }
  @utf8.decode(Bytes::from_array(buf[:len])) catch {
    _ => raise Message("the input is not valid UTF-8")
  }
}

///|
/// Reads a secret without it ever appearing on screen or in an argument list.
/// On a terminal it prints `prompt` to stderr and reads one line with echo
/// off; otherwise it reads all of stdin so `printf '%s' "$KEY" | ...` works.
///
/// # Raises
/// `TtyError` when the input cannot be read or is not UTF-8.
pub async fn read_secret(prompt : String) -> String {
  if ffi_is_terminal() == 0 {
    return @stdio.stdin.read_all().text() catch {
        _ => raise Message("could not read from stdin")
      }
  }
  @stdio.stderr.write(prompt)
  let secret = read_hidden_line()
  @stdio.stderr.write("\n")
  secret
}
