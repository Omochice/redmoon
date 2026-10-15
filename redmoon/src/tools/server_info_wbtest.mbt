///|
async test "redmoon_info reports the version and a null build from source" {
  let called = call_tool([server_info_tool(build=None)], "redmoon_info", {
    "show": {},
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"version\":\"\{@build.VERSION}\",\"build\":null}")
}

///|
async test "redmoon_info reports the build when one is embedded" {
  let build = Some(BuildInfo::{ commit: "abc123", dirty: true, })
  let called = call_tool([server_info_tool(build~)], "redmoon_info", {
    "show": {},
  })
  assert_eq(
    called.text,
    "{\"version\":\"\{@build.VERSION}\",\"build\":{\"commit\":\"abc123\",\"dirty\":true}}",
  )
}

///|
test "the checked-in build info is empty" {
  assert_true(current_build() is None)
}
