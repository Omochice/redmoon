///|
test "a success holds the JSON of the value" {
  let result = success(["a", "b"])
  assert_eq(result.is_error, false)
  assert_eq(text_of(result), "[\"a\",\"b\"]")
}

///|
test "success_ok answers ok" {
  assert_eq(text_of(success_ok()), "{\"ok\":true}")
}

///|
test "a response error keeps its status and messages" {
  let result = failure_of(
    Response(status=422, errors=["Subject cannot be blank"]),
  )
  assert_eq(result.is_error, true)
  assert_eq(
    text_of(result),
    "{\"status\":422,\"errors\":[\"Subject cannot be blank\"]}",
  )
}

///|
test "a transport error has status 0" {
  assert_eq(
    text_of(failure_of(Transport(message="connection refused"))),
    "{\"status\":0,\"errors\":[\"connection refused\"]}",
  )
}

///|
test "a local failure has status 0" {
  assert_eq(
    text_of(local_failure(["a", "b"])),
    "{\"status\":0,\"errors\":[\"a\",\"b\"]}",
  )
}

///|
async test "respond maps a raised error to a failure" {
  let result : @mcp.ToolResult = respond(fn() -> Int32 raise @redmine.RedmineError {
    raise Response(status=404, errors=["Not Found"])
  })
  assert_eq(result.is_error, true)
  assert_eq(text_of(result), "{\"status\":404,\"errors\":[\"Not Found\"]}")
}

///|
async test "respond_ok answers ok when the call returns" {
  let result = respond_ok(fn() raise @redmine.RedmineError {
    if false {
      raise Transport(message="unused")
    }
  })
  assert_eq(result.is_error, false)
  assert_eq(text_of(result), "{\"ok\":true}")
}

///|
test "on_invalid prefixes each message" {
  let error = @schema.SchemaError::Many([
    Invalid(path=["show", "id"], message="must be at least 1"),
    Invalid(path=[], message="expected an object"),
  ])
  assert_eq(
    text_of(on_invalid(error)),
    "{\"status\":0,\"errors\":[\"invalid arguments: show.id: must be at least 1\",\"invalid arguments: expected an object\"]}",
  )
}

///|
test "describe_crud_tool drops the write verbs in readonly mode" {
  assert_eq(
    describe_crud_tool("issues", Readonly),
    "List and show Redmine issues. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.",
  )
  assert_eq(
    describe_crud_tool("wiki pages", Full),
    "Create, read, update, and delete Redmine wiki pages. Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{\"<operation>\": {...}}`.",
  )
}

///|
test "project_ref accepts an id or an identifier without whitespace" {
  let schema = project_ref()
  assert_eq(schema.parse(Json(7)), @redmine.ProjectRef::Id(7))
  assert_eq(schema.parse(Json("demo")), @redmine.ProjectRef::Identifier("demo"))
  assert_true(
    try (schema.parse(Json("a b")) is (_ : @redmine.ProjectRef)) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}
