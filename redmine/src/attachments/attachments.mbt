///|
/// A size in bytes as Redmine reports it, which may exceed the range of `Int32`.
#derive(Eq, Debug)
pub(all) struct ByteSize(Int64)

///|
pub extend ByteSize with Eq::{equal, not_equal}

///|
pub extend ByteSize with @debug.Debug::{to_repr}

///|
pub extend ByteSize with @json.FromJson::{from_json}

///|
pub extend ByteSize with ToJson::{to_json}

///|
/// Core's `Int64` codec reads and writes a JSON string, while Redmine sends a size as a number.
pub impl @json.FromJson for ByteSize with fn from_json(json, path) {
  guard json is Number(d, ..) &&
    d == d.floor() &&
    d >= 0.0 &&
    d < 9223372036854775808.0 else {
    raise @json.JsonDecodeError(
      (path, "ByteSize::from_json: expected a non-negative integer"),
    )
  }
  ByteSize(d.to_int64())
}

///|
/// Written as a number for the same reason it is read as one.
pub impl ToJson for ByteSize with fn to_json(self) {
  Json::number(self.0.to_double())
}

///|
/// The size as a number of bytes.
pub fn ByteSize::to_int64(self : ByteSize) -> Int64 {
  self.0
}

///|
/// A file attached to a Redmine record.
#derive(FromJson, ToJson, Eq, Debug)
pub(all) struct Attachment {
  id : Int32
  filename : String
  filesize : ByteSize
  content_type : String?
  description : String?
  content_url : String
  thumbnail_url : String?
  author : @redmine.IdName
  created_on : String
}

///|
pub extend Attachment with @json.FromJson::{from_json}

///|
pub extend Attachment with ToJson::{to_json}

///|
pub extend Attachment with Eq::{equal, not_equal}

///|
pub extend Attachment with @debug.Debug::{to_repr}

///|
/// Returns the metadata of the attachment `id`.
/// Raises `Response` with status 404 when it does not exist.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let attachment = (redmine |> @attachments.show(3)) catch {
///     @redmine.Response(status=404, ..) => return
///     error => raise error
///   }
///   ignore(attachment)
/// }
/// ```
pub async fn show(
  redmine : @redmine.Redmine,
  id : Int32,
) -> Attachment raise @redmine.RedmineError {
  let json = redmine |> @redmine.send(Get, ["attachments", "\{id}.json"])
  @decode.decode_field(json, "attachment")
}

///|
/// Streams the content of the attachment `id` into `consume`, together with its metadata.
/// The connection is closed when `consume` returns or raises, and the reader must not outlive it.
/// Errors raised by `consume` propagate unchanged; every failure of the download itself is a `RedmineError`.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine
///   |> @attachments.download(3, (attachment, body) => {
///     let content = body.read_all().binary()
///     ignore((attachment.filename, content))
///   })
/// }
/// ```
pub async fn download(
  redmine : @redmine.Redmine,
  id : Int32,
  consume : async (Attachment, &@io.Reader) -> Unit,
) -> Unit {
  let attachment = redmine |> show(id)
  let mut location = content_location(redmine, attachment)
  for followed = 0; followed <= MAX_REDIRECTS; followed = followed + 1 {
    let client = @core.open_client(
      @redmine.connection(redmine),
      location.origin,
    ) catch {
      error => raise @redmine.Transport(message="\{error}")
    }
    let next = {
      errdefer client.close()
      fetch(client, location)
    }
    match next {
      Some(next) => {
        client.close()
        location = next
      }
      None => {
        defer client.close()
        consume(attachment, client)
        return
      }
    }
  }
  raise @redmine.Transport(
    message="attachment download followed more than \{MAX_REDIRECTS} redirects",
  )
}

///|
/// Uploads the `size` bytes of `body` and returns the token that attaches them
/// to a record through the `uploads` field of an update.
/// `body` stays the caller's: close it when done, because a failed upload returns
/// without draining it.
///
/// ```mbt check
/// #skip("needs a live Redmine")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let content = b"hello"
///   let reader = @io.MemoryReader(w => w.write(content))
///   defer reader.close()
///   let token = redmine
///     |> @attachments.upload(
///       reader,
///       content.length().to_int64(),
///       filename="hello.txt",
///     )
///   ignore(token)
/// }
/// ```
pub async fn upload(
  redmine : @redmine.Redmine,
  body : &@io.Reader,
  size : Int64,
  filename~ : String,
) -> String raise @redmine.RedmineError {
  let (status, text) = post_upload(redmine, body, size, filename) catch {
    error => raise @redmine.Transport(message="\{error}")
  }
  let body = @redmine.unwrap(@core.interpret(status, text))
  let upload : Json = @decode.decode_field(body, "upload")
  @decode.decode_field(upload, "token")
}
