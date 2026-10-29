///|
/// A free-text argument, given inline or as a local file to read.
priv enum TextSource {
  Inline(String)
  File(String)
}

///|
const MAX_TEXT_SIZE : Int32 = 1048576

///|
fn text_path_text(field : String) -> String {
  "Local file holding the `\{field}` to send, as an alternative to `\{field}` for a long text. The file must be UTF-8 and at most 1 MiB, is sent as is with its trailing newline but without a leading byte order mark, and cannot be combined with `\{field}`. An absolute path is recommended, because a relative one resolves against the working directory of the server process."
}

///|
/// The `_path` sibling of the free-text argument `field`.
fn text_path(field : String) -> @schema.Field[String?] {
  @schema.optional(field + "_path", path_schema(text_path_text(field)))
}

///|
/// A local file path argument described by `description`.
fn path_schema(description : String) -> @schema.Schema[String] {
  @schema.not_blank().describe(description)
}

///|
/// Checked on the raw object before `schema` parses it, because a record build
/// cannot tell the path it is parsing and so could not point at `field_path`.
fn[T] exclusive_text(
  schema : @schema.Schema[T],
  field~ : String,
  required~ : Bool = false,
) -> @schema.Schema[T] {
  let file = field + "_path"
  {
    json: schema.json,
    decode: (input, path) => {
      if input is Object(fields) {
        let message = match (fields.contains(field), fields.contains(file)) {
          (true, true) =>
            Some("`\{field}` and `\{file}` cannot be given together")
          (false, false) if required =>
            Some("one of `\{field}` and `\{file}` is required")
          _ => None
        }
        if message is Some(message) {
          raise @schema.SchemaError::Invalid(path=[..path, file], message~)
        }
      }
      (schema.decode)(input, path)
    },
  }
}

///|
/// Counts the bytes as they stream because the size the file declared when
/// opened is not the size it has by the time it is read.
async fn read_bounded(reader : &@io.Reader, path : String) -> Bytes {
  let buffer = Buffer()
  while reader.read_some() is Some(chunk) {
    buffer.write_bytes(chunk)
    if buffer.length() > MAX_TEXT_SIZE {
      raise FileError(
        message="\{path} exceeds the limit of \{MAX_TEXT_SIZE} bytes (1 MiB)",
      )
    }
  }
  buffer.to_bytes()
}

///|
async fn read_text_file(
  files : &FilePort,
  path : String,
) -> String raise FileError {
  let content = files.open(path)
  defer (content.close)()
  if content.size > MAX_TEXT_SIZE.to_int64() {
    raise FileError(
      message="\{path} is \{content.size} bytes, which exceeds the limit of \{MAX_TEXT_SIZE} bytes (1 MiB)",
    )
  }
  let bytes = read_bounded(content.reader, path) catch {
    FileError(_) as e => raise e
    error => raise FileError(message="\{path}: \{error}")
  }
  @utf8.decode(bytes, ignore_bom=true) catch {
    _ => raise FileError(message="\{path} is not valid UTF-8")
  }
}

///|
async fn TextSource::read(
  self : TextSource,
  files : &FilePort,
) -> String raise FileError {
  match self {
    Inline(text) => text
    File(path) => read_text_file(files, path)
  }
}

///|
async fn read_optional_file(
  files : &FilePort,
  path : String?,
) -> String? raise FileError {
  match path {
    Some(path) => Some(read_text_file(files, path))
    None => None
  }
}

///|
fn file_or_inline(file : String?, inline : String?) -> String? {
  match file {
    Some(_) => file
    None => inline
  }
}
