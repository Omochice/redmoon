///|
test "decode_field unwraps the envelope a plugin answers in" {
  let value : Int32 = decode_field({ "row": 3 }, "row") catch {
    _ => fail("decode")
  }
  assert_eq(value, 3)
}

///|
test "decode_field reports an answer without the envelope's key as Decode" {
  try decode_field(Json::object({}), "row") catch {
    Decode(message~) =>
      assert_eq(
        message, "Redmine answered, but the response could not be read: it has no `row`",
      )
    error => fail(Json(error).stringify())
  } noraise {
    (_ : Int32) => fail("expected a missing key to be reported")
  }
}
