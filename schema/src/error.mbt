///|
/// A validation failure. `Invalid` is one failed value; `Many` groups the
/// failures reported together, such as several unknown keys.
pub(all) suberror SchemaError {
  Invalid(path~ : Array[String], message~ : String)
  Many(Array[SchemaError])
}

///|
/// Every failed value of the error as `a.b.c: message`, or just `message` when
/// the failure is at the root. Duplicates are dropped.
pub fn SchemaError::messages(self : SchemaError) -> Array[String] {
  let out : Array[String] = []
  for leaf in self.leaves() {
    let (path, message) = leaf
    let text = if path.is_empty() { message } else { path.join(".") + ": " + message }
    if !out.contains(text) {
      out.push(text)
    }
  }
  out
}

///|
/// The failures of the error joined into one line.
pub fn SchemaError::message(self : SchemaError) -> String {
  self.messages().join("; ")
}

///|
pub impl Show for SchemaError with output(self, logger) {
  logger.write_string(self.message())
}

///|
fn SchemaError::leaves(self : SchemaError) -> Array[(Array[String], String)] {
  match self {
    Invalid(path~, message~) => [(path, message)]
    Many(errors) => {
      let out : Array[(Array[String], String)] = []
      for e in errors {
        out.append(e.leaves())
      }
      out
    }
  }
}

///|
fn[T] fail(path : Array[String], message : String) -> T raise SchemaError {
  raise Invalid(path~, message~)
}

///|
pub extend SchemaError with Show::{to_string, output}
