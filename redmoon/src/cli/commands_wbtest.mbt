///|
struct FakeStore {
  entries : Map[String, String]
}

///|
impl CredentialStore for FakeStore with fn get(self, account) {
  self.entries.get(account)
}

///|
impl CredentialStore for FakeStore with fn set(self, account, secret) {
  self.entries[account] = secret
}

///|
impl CredentialStore for FakeStore with fn delete(self, account) {
  self.entries.remove(account)
}

///|
impl CredentialStore for FakeStore with fn list(self) {
  self.entries.keys().collect()
}

///|
fn fake(entries : Array[(String, String)]) -> FakeStore {
  { entries: Map::from_array(entries), }
}

///|
async test "login stores the trimmed key under the canonical account" {
  let store = fake([])
  let account = run_login("https://R.example.com/", store, fn() { "  abc123\n" })
  inspect(account, content="https://r.example.com")
  @debug.debug_inspect(
    store.entries.get("https://r.example.com"),
    content="Some(\"abc123\")",
  )
}

///|
async test "login rejects an empty key" {
  let store = fake([])
  try run_login("https://r.example.com", store, fn() { "   \n" }) catch {
    e => inspect(e, content="no API key was provided")
  } noraise {
    _ => fail("an empty key was stored")
  }
  assert_true(store.entries.is_empty())
}

///|
test "resolve returns the stored key for the canonical account" {
  let store = fake([("https://r.example.com", "k")])
  let credential = resolve_api_key("https://r.example.com/", store)
  inspect(credential.endpoint, content="https://r.example.com")
  inspect(credential.api_key, content="k")
}

///|
test "resolve tells the user to log in when no key is stored" {
  try resolve_api_key("https://r.example.com/", fake([])) catch {
    e =>
      inspect(
        e,
        content="no stored API key for https://r.example.com; run `login --endpoint https://r.example.com` first",
      )
  } noraise {
    _ => fail("a missing key was resolved")
  }
}

///|
test "logout removes the stored key" {
  let store = fake([("https://r.example.com", "k")])
  inspect(
    run_logout("https://r.example.com/", store),
    content="https://r.example.com",
  )
  assert_true(store.entries.is_empty())
}

///|
test "list is sorted and empty when nothing is stored" {
  let store = fake([
    ("https://b.example.com", "2"),
    ("https://a.example.com", "1"),
  ])
  @debug.debug_inspect(
    run_list(store),
    content="[\"https://a.example.com\", \"https://b.example.com\"]",
  )
  @debug.debug_inspect(run_list(fake([])), content="[]")
}
