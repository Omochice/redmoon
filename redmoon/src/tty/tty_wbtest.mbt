///|
/// `login` prints the error to the user as is, so the text must carry nothing but the message.
/// The constructor is not `pub(all)`, which keeps this test white-box.
test "the error is shown as its message alone" {
  let error : TtyError = Message("could not read from the terminal")
  assert_eq(error.to_string(), "could not read from the terminal")
  assert_eq("\{error}", "could not read from the terminal")
}
