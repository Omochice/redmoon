///|
/// A file attached to a Redmine record.
pub(all) struct Attachment {
  id : Int32
  filename : String
  filesize : Int32
  content_type : String
  description : String?
  content_url : String
  thumbnail_url : String?
  author : @redmine.IdName
  created_on : String
} derive(FromJson, ToJson, Eq, Debug)

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
  let body = match @core.interpret(status, text) {
    Body(json) => json
    Rejected(status~, errors~) => raise @redmine.Response(status~, errors~)
    Malformed(message~) => raise @redmine.Transport(message~)
  }
  let upload : Json = @decode.decode_field(body, "upload")
  @decode.decode_field(upload, "token")
}
