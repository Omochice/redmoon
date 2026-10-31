///|
/// A failure of the local filesystem, carrying the message shown to the model.
pub suberror FileError {
  FileError(message~ : String)
}

///|
/// A local file opened for reading.
/// `close` releases the file whether or not the reader was drained.
pub(all) struct LocalContent {
  filename : String
  size : Int64
  reader : &@io.Reader
  close : () -> Unit
}

///|
/// The local filesystem access the tools depend on.
pub(open) trait FilePort {
  /// Writes `reader` to a new file at `path` and returns the absolute path
  /// written. An existing file is never replaced, and a stream longer than
  /// `max_size` bytes is aborted with its partial file removed.
  async fn save(Self, String, &@io.Reader, Int64) -> String raise FileError
  /// Opens the regular file at `path` for reading.
  async fn open(Self, String) -> LocalContent raise FileError
}

///|
/// The last segment of a path written with `/` or `\`.
fn last_segment(path : String) -> String {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  match (slash, backslash) {
    (Some(i), Some(j)) => path[i.max(j) + 1:].to_owned()
    (Some(i), None) | (None, Some(i)) => path[i + 1:].to_owned()
    (None, None) => path
  }
}
