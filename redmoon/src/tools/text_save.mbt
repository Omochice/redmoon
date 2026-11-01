///|
fn save_path_text(field : String) -> String {
  "Destination file for the `\{field}`. When given, the `\{field}` is written to this file with its line breaks as `\\n`, and the response gives the absolute path written as `\{field}_path` in place of `\{field}`. An absolute path is recommended, because a relative one resolves against the working directory of the server process. The file must not already exist."
}

///|
/// The optional `_path` argument of `show` that saves the free text `field`.
fn save_path(field : String) -> @schema.Field[String?] {
  @schema.optional(field + "_path", path_schema(save_path_text(field)))
}

///|
/// Redmine answers line breaks as `\r\n` while local edit tools write `\n`,
/// so a saved file left as `\r\n` would mix both once it is edited.
/// The limit passed to `save` is the exact length, since the text is already
/// in memory and no limit should refuse it.
async fn save_text(
  files : &FilePort,
  path : String,
  text : String,
) -> String raise FileError {
  let bytes = @utf8.encode(text.replace_all(old="\r\n", new="\n"))
  let reader = @io.MemoryReader(w => w.write(bytes))
  defer reader.close()
  files.save(path, reader, bytes.length().to_int64())
}

///|
fn with_saved_path(value : Json, field : String, written : String) -> Json {
  guard value is Object(fields) else { return value }
  fields.remove(field)
  fields[field + "_path"] = Json::string(written)
  value
}

///|
async fn respond_saving_text(
  files : &FilePort,
  value : Json,
  field : String,
  text : String,
  path : String?,
) -> @mcp.ToolResult {
  guard path is Some(path) else { return success(value) }
  let written = save_text(files, path, text) catch {
    FileError(message~) => return local_failure([message])
  }
  success(with_saved_path(value, field, written))
}
