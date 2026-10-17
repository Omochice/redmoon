///|
test "the success status raises nothing" {
  check(ok)
}

///|
test "the no-store status raises NoStore" {
  try check(no_store) catch {
    NoStore(_) => ()
    _ => fail("raised a different error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "any other status raises Refused with the native code" {
  try check(-25308) catch {
    Refused(-25308) => ()
    _ => fail("raised a different error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "a secret that is not UTF-8 is refused" {
  try decode(b"\xff\xfe") catch {
    Refused(-1) => ()
    _ => fail("raised a different error")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "account text splits into one account per line" {
  assert_eq(parse_accounts("alice\nbob\n"), ["alice", "bob"])
}

///|
test "empty account text means no accounts" {
  assert_eq(parse_accounts(""), [])
}
