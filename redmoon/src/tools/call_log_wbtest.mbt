///|
/// The calls a fake received, and the failure it answers every call with.
struct CallLog {
  calls : Array[String]
  failure : @redmine.RedmineError?
}

///|
fn CallLog::new(failure? : @redmine.RedmineError) -> CallLog {
  { calls: [], failure, }
}

///|
/// Logs before raising, so a test can tell a call that failed from one never made.
fn CallLog::record(
  self : CallLog,
  call : String,
) -> Unit raise @redmine.RedmineError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}
