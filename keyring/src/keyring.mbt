///|
/// Failure to reach a credential store, or a store refusing one operation.
///
/// ```mbt check
/// #skip("touches the OS credential store")
/// test {
///   @keyring.set("my-app", "alice", "secret") catch {
///     NoStore(message) => println(message)
///     Refused(code) => println("store refused the write: \{code}")
///   }
/// }
/// ```
pub suberror KeyringError {
  /// No credential store can be opened; the payload tells the user what to install or start.
  NoStore(String)
  /// The store rejected the operation; the payload is its native error code.
  Refused(Int32)
}

///|
#borrow(service, account, secret)
extern "C" fn ffi_set(
  service : Bytes,
  account : Bytes,
  secret : Bytes,
) -> Int32 = "omochice_keyring_set"

///|
#borrow(service, account)
extern "C" fn ffi_get(service : Bytes, account : Bytes) -> Int32 = "omochice_keyring_get"

///|
#borrow(service, account)
extern "C" fn ffi_delete(service : Bytes, account : Bytes) -> Int32 = "omochice_keyring_delete"

///|
#borrow(service)
extern "C" fn ffi_list(service : Bytes) -> Int32 = "omochice_keyring_list"

///|
extern "C" fn ffi_result_size() -> Int32 = "omochice_keyring_result_size"

///|
#borrow(dst)
extern "C" fn ffi_result_take(dst : Bytes) = "omochice_keyring_result_take"

///|
let ok : Int32 = 0

///|
let not_found : Int32 = 1000000001

///|
let no_store : Int32 = 1000000002

///|
fn check(status : Int32) -> Unit raise KeyringError {
  if status == ok {
    return
  }
  if status == no_store {
    raise NoStore(
      "no credential store is available; on Linux install libsecret and run a Secret Service provider such as gnome-keyring",
    )
  }
  raise Refused(status)
}

///|
fn take_result() -> Bytes {
  let dst = Bytes::make(ffi_result_size(), 0)
  ffi_result_take(dst)
  dst
}

///|
/// A store holding bytes that are not UTF-8 is reported as refusing, since the secret cannot be returned as text.
fn decode(bytes : Bytes) -> String raise KeyringError {
  @utf8.decode(bytes) catch {
    _ => raise Refused(-1)
  }
}

///|
/// Returns the secret stored for `service` and `account`, or `None` when there is none.
///
/// # Raises
/// `NoStore` when no credential store is reachable, `Refused` when the store rejects the read.
///
/// ```mbt check
/// #skip("touches the OS credential store")
/// test {
///   match @keyring.get("my-app", "alice") {
///     Some(token) => ignore(token)
///     None => ()
///   }
/// }
/// ```
pub fn get(service : String, account : String) -> String? raise KeyringError {
  let status = ffi_get(@utf8.encode(service), @utf8.encode(account))
  if status == not_found {
    return None
  }
  check(status)
  let secret = take_result()
  Some(decode(secret))
}

///|
/// Stores `secret` for `service` and `account`, replacing any existing one.
///
/// # Raises
/// `NoStore` when no credential store is reachable, `Refused` when the store rejects the write.
///
/// ```mbt check
/// #skip("touches the OS credential store")
/// test {
///   @keyring.set("my-app", "alice", "secret")
/// }
/// ```
pub fn set(
  service : String,
  account : String,
  secret : String,
) -> Unit raise KeyringError {
  check(
    ffi_set(@utf8.encode(service), @utf8.encode(account), @utf8.encode(secret)),
  )
}

///|
/// Removes the secret for `service` and `account`; does nothing when there is none.
///
/// # Raises
/// `NoStore` when no credential store is reachable, `Refused` when the store rejects the removal.
///
/// ```mbt check
/// #skip("touches the OS credential store")
/// test {
///   @keyring.delete("my-app", "alice")
/// }
/// ```
pub fn delete(service : String, account : String) -> Unit raise KeyringError {
  let status = ffi_delete(@utf8.encode(service), @utf8.encode(account))
  if status == not_found {
    return
  }
  check(status)
}

///|
/// Returns the accounts that hold a secret under `service`.
///
/// # Raises
/// `NoStore` when no credential store is reachable, `Refused` when the store rejects the query.
///
/// ```mbt check
/// #skip("touches the OS credential store")
/// test {
///   for account in @keyring.list("my-app") {
///     ignore(account)
///   }
/// }
/// ```
pub fn list(service : String) -> Array[String] raise KeyringError {
  check(ffi_list(@utf8.encode(service)))
  let accounts = []
  for line in decode(take_result()).split("\n") {
    if line.length() > 0 {
      accounts.push(line.to_owned())
    }
  }
  accounts
}
