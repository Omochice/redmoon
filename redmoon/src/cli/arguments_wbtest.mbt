///|
test "serve takes an endpoint and an optional readonly flag" {
  @debug.debug_inspect(
    parse_arguments(argv=["serve", "--endpoint", "https://r.example.com"]),
    content="Serve(endpoint=\"https://r.example.com\", read_only=false)",
  )
  @debug.debug_inspect(
    parse_arguments(argv=[
      "serve", "--endpoint", "https://r.example.com", "--readonly",
    ]),
    content="Serve(endpoint=\"https://r.example.com\", read_only=true)",
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
