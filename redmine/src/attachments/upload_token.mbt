///|
/// A file uploaded beforehand, to attach to a record.
#derive(ToJson, Eq, Debug)
pub(all) struct UploadToken {
  token : String
  filename : String?
  description : String?
  content_type : String?
}

///|
pub extend UploadToken with Eq::{equal, not_equal}

///|
pub extend UploadToken with @debug.Debug::{to_repr}

///|
pub extend UploadToken with ToJson::{to_json}

///|
/// A token as `@attachments.upload` returns it, with the optional file details.
///
/// ```mbt check
/// test {
///   let token = @attachments.UploadToken::new(
///     "7167.ed1ccdb093229ca1bd0b043618d88743",
///   )
///   assert_eq(token.filename, None)
///   let named = @attachments.UploadToken::new(
///     "7168.0f3c",
///     filename="report.pdf",
///     content_type="application/pdf",
///   )
///   assert_eq(named.filename, Some("report.pdf"))
/// }
/// ```
pub fn UploadToken::new(
  token : String,
  filename? : String,
  description? : String,
  content_type? : String,
) -> UploadToken {
  { token, filename, description, content_type, }
}
