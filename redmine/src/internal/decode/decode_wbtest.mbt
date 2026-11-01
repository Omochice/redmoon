///|
test "a shape mismatch raises Decode naming the JSON path" {
  try decode_field({ "issues": [{ "id": "x" }] }, "issues") catch {
    Decode(message~) =>
      assert_eq(
        message, "The server answered, but the response could not be read: Int::from_json: expected number at `/issues/0/id`",
      )
    error => fail(Json(error).stringify())
  } noraise {
    (_ : Array[Map[String, Int32]]) => fail("expected a shape mismatch")
  }
}

///|
test "a mismatch at the top level names the root path" {
  try decode(Json::string("x")) catch {
    Decode(message~) =>
      assert_eq(
        message, "The server answered, but the response could not be read: Int::from_json: expected number at `/`",
      )
    error => fail(Json(error).stringify())
  } noraise {
    (_ : Int32) => fail("expected a shape mismatch")
  }
}

///|
test "an answer without the envelope's key raises Decode" {
  try decode_field(Json::object({}), "issue") catch {
    Decode(message~) =>
      assert_eq(
        message, "The server answered, but the response could not be read: it has no `issue`",
      )
    error => fail(Json(error).stringify())
  } noraise {
    (_ : Int32) => fail("expected a missing key to be reported")
  }
}
