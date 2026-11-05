///|
test "serve takes an endpoint and an optional readonly flag" {
  @debug.debug_inspect(
    @cli.parse_arguments(argv=["serve", "--endpoint", "https://r.example.com"]),
    content="Serve(endpoint=\"https://r.example.com\", read_only=false, plugins=[])",
  )
  @debug.debug_inspect(
    @cli.parse_arguments(argv=[
      "serve", "--endpoint", "https://r.example.com", "--readonly",
    ]),
    content="Serve(endpoint=\"https://r.example.com\", read_only=true, plugins=[])",
  )
}

///|
test "login, logout and list" {
  assert_eq(
    @cli.parse_arguments(argv=["login", "--endpoint", "http://localhost:3000"]),
    @cli.Login(endpoint="http://localhost:3000"),
  )
  assert_eq(
    @cli.parse_arguments(argv=["logout", "--endpoint", "http://localhost:3000"]),
    @cli.Logout(endpoint="http://localhost:3000"),
  )
  assert_eq(@cli.parse_arguments(argv=["list"]), @cli.List)
}

///|
test "a missing endpoint or subcommand is rejected with the usage" {
  for argv in [["serve"], ["login"], ["logout"], ["frobnicate"]] {
    try @cli.parse_arguments(argv~) catch {
      error =>
        assert_true(
          error.to_string().contains("\nUsage: redmoon"),
          msg="\{argv.join(" ")} was rejected without the usage: \{error}",
        )
    } noraise {
      _ => fail("\{argv.join(" ")} was accepted")
    }
  }
}

///|
test "serve enables each plugin named by a repeatable --plugin" {
  let serve = ["serve", "--endpoint", "https://r.example.com"]
  assert_eq(
    @cli.parse_arguments(argv=[..serve, "--plugin", "issue_templates"]),
    @cli.Serve(endpoint="https://r.example.com", read_only=false, plugins=[
      @cli.IssueTemplates,
    ]),
  )
  assert_eq(
    @cli.parse_arguments(
      argv=[
        ..serve, "--plugin", "issue_templates", "--readonly", "--plugin", "issue_templates",
      ],
    ),
    @cli.Serve(endpoint="https://r.example.com", read_only=true, plugins=[
      @cli.IssueTemplates,
    ]),
  )
}

///|
test "an unknown plugin is rejected with the known names" {
  try
    @cli.parse_arguments(argv=[
      "serve", "--endpoint", "https://r.example.com", "--plugin", "checklists",
    ])
  catch {
    error =>
      assert_eq(
        error.to_string(),
        "unknown plugin `checklists`; known plugins: issue_templates, agile, additional_tags",
      )
  } noraise {
    _ => fail("an unknown plugin was accepted")
  }
}

///|
test "serve enables the agile plugin alongside issue templates" {
  assert_eq(
    @cli.parse_arguments(argv=[
      "serve", "--endpoint", "https://r.example.com", "--plugin", "agile", "--plugin",
      "issue_templates",
    ]),
    @cli.Serve(endpoint="https://r.example.com", read_only=false, plugins=[
      @cli.Agile,
      @cli.IssueTemplates,
    ]),
  )
}

///|
test "serve enables the additional tags plugin" {
  assert_eq(
    @cli.parse_arguments(argv=[
      "serve", "--endpoint", "https://r.example.com", "--plugin", "additional_tags",
    ]),
    @cli.Serve(endpoint="https://r.example.com", read_only=false, plugins=[
      @cli.AdditionalTags,
    ]),
  )
}
