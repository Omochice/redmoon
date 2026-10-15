///|
/// A fake resource of `total` integers that records every `(limit, offset)` asked for.
fn fake_fetcher(
  total : Int32,
  calls : Array[(Int32, Int32)],
) -> async (Int32, Int32) -> Page[Int32] raise RedmineError {
  fn(size, offset) {
    calls.push((size, offset))
    let items = []
    for i = offset; i < @cmp.minimum(offset + size, total); i = i + 1 {
      items.push(i)
    }
    { items, total_count: total, }
  }
}

///|
async test "without limit every page is fetched using total_count" {
  let calls = []
  let items = walk_pages(fake_fetcher(250, calls))
  assert_eq(items.length(), 250)
  assert_eq(items[249], 249)
  @debug.debug_inspect(calls, content="[(100, 0), (100, 100), (100, 200)]")
}

///|
async test "without limit an exact multiple does not request an empty page" {
  let calls = []
  let items = walk_pages(fake_fetcher(200, calls))
  assert_eq(items.length(), 200)
  @debug.debug_inspect(calls, content="[(100, 0), (100, 100)]")
}

///|
async test "without limit an empty resource takes one request" {
  let calls = []
  let items = walk_pages(fake_fetcher(0, calls))
  assert_eq(items.length(), 0)
  @debug.debug_inspect(calls, content="[(100, 0)]")
}

///|
async test "limit shrinks the last page request" {
  let calls = []
  let items = walk_pages(fake_fetcher(1000, calls), limit=250)
  assert_eq(items.length(), 250)
  @debug.debug_inspect(calls, content="[(100, 0), (100, 100), (50, 200)]")
}

///|
async test "limit stops at a short page" {
  let calls = []
  let items = walk_pages(fake_fetcher(130, calls), limit=500)
  assert_eq(items.length(), 130)
  @debug.debug_inspect(calls, content="[(100, 0), (100, 100)]")
}

///|
async test "limit is not exceeded by an over-full page" {
  let items = walk_pages(
    fn(_size, _offset) { { items: [1, 2, 3, 4, 5], total_count: 5, } },
    limit=3,
  )
  @debug.debug_inspect(items, content="[1, 2, 3]")
}

///|
async test "a failing page raises" {
  try
    walk_pages(fn(_size, offset) raise RedmineError {
      guard offset == 0 else { raise Transport(message="down") }
      { items: Array::makei(100, fn(i) { i }), total_count: 300, }
    })
  catch {
    Transport(message~) => assert_eq(message, "down")
    _ => fail("expected Transport")
  } noraise {
    _ => fail("expected an error")
  }
}
