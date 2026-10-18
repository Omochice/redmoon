///|
test "serve takes an endpoint and an optional readonly flag" {
  @debug.debug_inspect(
    parse_arguments(argv=["serve", "--endpoint", "https://r.example.com"]),
    content="Serve(endpoint=\"https://r.example.com\", read_only=false, plugins=[])",
  )
  @debug.debug_inspect(
    parse_arguments(argv=[
      "serve", "--endpoint", "https://r.example.com", "--readonly",
    ]),
    content="Serve(endpoint=\"https://r.example.com\", read_only=true, plugins=[])",
  )
}

///|
test "login, logout and list" {
  assert_eq(
    parse_arguments(argv=["login", "--endpoint", "http://localhost:3000"]),
    Login(endpoint="http://localhost:3000"),
  )
  assert_eq(
    parse_arguments(argv=["logout", "--endpoint", "http://localhost:3000"]),
    Logout(endpoint="http://localhost:3000"),
  )
  assert_eq(parse_arguments(argv=["list"]), List)
}

///|
test "a missing endpoint or subcommand is rejected" {
  for argv in [["serve"], ["login"], ["logout"], ["frobnicate"]] {
    try parse_arguments(argv~) catch {
      _ => ()
    } noraise {
      _ => fail("\{argv.join(" ")} was accepted")
    }
  }
}

///|
test "serve enables each plugin named by a repeatable --plugin" {
  let serve = ["serve", "--endpoint", "https://r.example.com"]
  assert_eq(
    parse_arguments(argv=[..serve, "--plugin", "issue_templates"]),
    Serve(endpoint="https://r.example.com", read_only=false, plugins=[
      IssueTemplates,
    ]),
  )
  assert_eq(
    parse_arguments(
      argv=[
        ..serve, "--plugin", "issue_templates", "--readonly", "--plugin", "issue_templates",
      ],
    ),
    Serve(endpoint="https://r.example.com", read_only=true, plugins=[
      IssueTemplates,
    ]),
  )
}

///|
test "an unknown plugin is rejected with the known names" {
  try
    parse_arguments(argv=[
      "serve", "--endpoint", "https://r.example.com", "--plugin", "agile",
    ])
  catch {
    error =>
      assert_eq(
        error.to_string(),
        "unknown plugin `agile`; known plugins: issue_templates",
      )
  } noraise {
    _ => fail("an unknown plugin was accepted")
  }
}
