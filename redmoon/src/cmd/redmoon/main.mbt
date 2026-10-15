///|
extern "c" fn exit(code : Int32) = "exit"

///|
async fn run() -> Unit {
  let store = @cli.OsKeyring::{ }
  match @cli.parse_arguments() {
    Serve(endpoint~, read_only~) => @cli.run_serve(endpoint, read_only, store)
    Login(endpoint~) => {
      let account = @cli.run_login(endpoint, store, async fn() {
        @tty.read_secret("Redmine API key: ")
      })
      eprintln("Stored API key for \{account}.")
    }
    Logout(endpoint~) => {
      let account = @cli.run_logout(endpoint, store)
      eprintln("Removed API key for \{account}.")
    }
    List => {
      let endpoints = @cli.run_list(store)
      if endpoints.is_empty() {
        eprintln("No stored credentials.")
      }
      for endpoint in endpoints {
        println(endpoint)
      }
    }
  }
}

///|
async fn main {
  run() catch {
    error => {
      eprintln("error: \{error}")
      exit(1)
    }
  }
}
