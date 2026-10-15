///|
/// The real filesystem.
pub struct LocalFile {}

///|
pub fn LocalFile::new() -> LocalFile {
  LocalFile::{ }
}

///|
fn describe_failure(path : String, error : Error) -> FileError {
  FileError(message="\{path}: \{error}")
}

///|
/// Counts the bytes as they stream because the size a server declares is not
/// the size it sends.
async fn write_bounded(
  file : @fs.File,
  reader : &@io.Reader,
  max_size : Int64,
) -> Unit {
  let mut written = 0L
  while reader.read_some() is Some(chunk) {
    written += chunk.length().to_int64()
    if written > max_size {
      raise FileError(
        message="content exceeds the max_size limit of \{max_size} bytes",
      )
    }
    file.write(chunk)
  }
}

///|
pub impl FilePort for LocalFile with fn save(_, path, reader, max_size) {
  let file = @fs.create(path, allow_existing=false) catch {
    error => raise describe_failure(path, error)
  }
  write_bounded(file, reader, max_size) catch {
    error => {
      file.close()
      // Best-effort, so a failed removal cannot hide the error that explains
      // why the download stopped.
      @fs.remove(path) catch {
        _ => ()
      }
      match error {
        FileError(_) as e => raise e
        _ => raise describe_failure(path, error)
      }
    }
  }
  file.close()
  @fs.realpath(path) catch {
    error => raise describe_failure(path, error)
  }
}

///|
pub impl FilePort for LocalFile with fn open(_, path) {
  let kind = @fs.kind(path) catch {
    error => raise describe_failure(path, error)
  }
  guard kind == Regular else {
    raise FileError(message="\{path} is not a regular file")
  }
  let file = @fs.open(path, mode=ReadOnly) catch {
    error => raise describe_failure(path, error)
  }
  let size = file.size() catch {
    error => {
      file.close()
      raise describe_failure(path, error)
    }
  }
  {
    filename: last_segment(path),
    size,
    reader: file,
    close: () => file.close(),
  }
}

///|
pub extend LocalFile with FilePort::{save, open}
