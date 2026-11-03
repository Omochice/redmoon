///|
extern "C" fn ffi_sentinel(which : Int32) -> Int32 = "omochice_keyring_sentinel"

///|
test "the MoonBit sentinels agree with keyring_common.h" {
  assert_eq(ffi_sentinel(0), ok)
  assert_eq(ffi_sentinel(1), not_found)
  assert_eq(ffi_sentinel(2), no_store)
  assert_eq(ffi_sentinel(3), INTERNAL)
}

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
    Refused(INTERNAL) => ()
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
