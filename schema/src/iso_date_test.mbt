///|
test "iso_date emits a date format" {
  assert_eq(
    schema_json(iso_date()),
    "{\"type\":\"string\",\"format\":\"date\"}",
  )
}

///|
test "iso_date accepts real dates" {
  for
    date in [
      "2026-10-16", "2028-02-29", "2000-02-29", "2026-12-31", "2026-01-01", "0001-01-01",
    ] {
    assert_eq(outcome(iso_date(), "\"\{date}\""), "ok: \"\{date}\"")
  }
}

///|
test "iso_date rejects impossible dates" {
  let message = "error: must be a date in the form YYYY-MM-DD"
  for
    date in [
      "2026-02-29", "1900-02-29", "2026-04-31", "2026-00-10", "2026-13-01", "2026-01-00",
      "2026-01-32",
    ] {
    assert_eq(outcome(iso_date(), "\"\{date}\""), message)
  }
}

///|
test "iso_date rejects malformed text" {
  let message = "error: must be a date in the form YYYY-MM-DD"
  for
    date in [
      "", "2026-1-01", "20261001", "2026/10/01", "2026-10-1x", "26-10-01", "2026-10-01T00:00",
      " 2026-10-01", "２０２６-10-01",
    ] {
    assert_eq(outcome(iso_date(), "\"\{date}\""), message)
  }
  assert_eq(outcome(iso_date(), "20261001"), "error: expected a string")
}
