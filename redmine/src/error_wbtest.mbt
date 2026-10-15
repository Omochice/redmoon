///|
test "errors_from_body reads Redmine's messages" {
  @debug.debug_inspect(
    errors_from_body(
      "{\"errors\":[\"Subject cannot be blank\",\"Name is invalid\"]}",
    ),
    content=(
      #|["Subject cannot be blank", "Name is invalid"]
    ),
  )
}

///|
test "errors_from_body yields nothing for an absent or foreign body" {
  @debug.debug_inspect(errors_from_body(""), content="[]")
  @debug.debug_inspect(errors_from_body("<html>502</html>"), content="[]")
  @debug.debug_inspect(errors_from_body("{\"error\":\"x\"}"), content="[]")
  @debug.debug_inspect(errors_from_body("{\"errors\":\"x\"}"), content="[]")
  @debug.debug_inspect(errors_from_body("{\"errors\":[1,2]}"), content="[]")
  @debug.debug_inspect(errors_from_body("[\"a\"]"), content="[]")
}
