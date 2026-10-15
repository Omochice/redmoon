///|
/// A file attached to a Redmine record.
pub(all) struct Attachment {
  id : Int32
  filename : String
  filesize : Int
  content_type : String
  description : String?
  content_url : String
  thumbnail_url : String?
  author : IdName
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
pub async fn Redmine::show_attachment(
  self : Redmine,
  id : Int,
) -> Attachment raise RedmineError {
  decode_field(self.get(["attachments", "\{id}.json"]), "attachment")
}

///|
/// Streams the content of the attachment `id` into `consume`, together with its metadata.
/// The connection is closed when `consume` returns or raises, and the reader must not outlive it.
/// Errors raised by `consume` propagate unchanged; every failure of the download itself is a `RedmineError`.
pub async fn Redmine::download_attachment(
  self : Redmine,
  id : Int,
  consume : async (Attachment, &@io.Reader) -> Unit raise,
) -> Unit raise {
  let attachment = self.show_attachment(id)
  let mut location = self.attachment_content_location(attachment)
  for followed = 0; followed <= MAX_REDIRECTS; followed = followed + 1 {
    let client = attachment_connect(
      location.origin,
      if same_origin(location.origin, self.endpoint.origin) {
        { "X-Redmine-API-Key": self.api_key }
      } else {
        {}
      },
    )
    let next = {
      errdefer client.close()
      attachment_fetch(client, location)
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
  raise Transport(
    message="attachment download followed more than \{MAX_REDIRECTS} redirects",
  )
}

///|
/// Uploads the `size` bytes of `body` and returns the token that attaches them
/// to a record through the `uploads` field of an update.
pub async fn Redmine::upload(
  self : Redmine,
  body : &@io.Reader,
  size : Int64,
  filename~ : String,
) -> String raise RedmineError {
  let (status, text) = self.attachment_post_upload(body, size, filename) catch {
    error => raise Transport(message="\{error}")
  }
  guard status >= 200 && status < 300 else {
    raise Response(status~, errors=errors_from_body(text))
  }
  let json = @json.parse(text) catch {
    error => raise Transport(message="invalid JSON in response: \{error}")
  }
  let upload : Json = decode_field(strip_nulls(json), "upload")
  decode_field(upload, "token")
}
