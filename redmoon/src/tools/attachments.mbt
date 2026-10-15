///|
priv enum AttachmentAction {
  Show(Int32)
  Download(Int32, String, Int32)
  Attach(Int32, String, String?, String?, String?)
}

///|
const DEFAULT_MAX_SIZE : Int32 = 524288000

///|
fn attachment_path(description : String) -> @schema.Schema[String] {
  @schema.not_blank().describe(description)
}

///|
fn attachment_input(mode : Mode) -> @schema.Schema[AttachmentAction] {
  let entries = [
    (
      "show",
      @schema.object(id => AttachmentAction::Show(id))
      |> @schema.field("id", record_id())
      |> @schema.Obj::done,
    ),
    (
      "download",
      @schema.object(id => path => max_size => Download(id, path, max_size))
      |> @schema.field("id", record_id())
      |> @schema.field(
        "path",
        attachment_path(
          "Destination file path for the saved content. An absolute path is recommended, because a relative one resolves against the working directory of the server process. The file must not already exist.",
        ),
      )
      |> @schema.optional_or(
        "max_size",
        @schema.integer(min=1).describe(
          "Maximum number of bytes to write, \{DEFAULT_MAX_SIZE} (500 MiB) by default. The download is refused, and nothing is saved, when the attachment turns out to be larger. Read `filesize` from `show` to choose a tighter limit.",
        ),
        DEFAULT_MAX_SIZE,
      )
      |> @schema.Obj::done,
    ),
  ]
  if mode is Full {
    entries.push(
      (
        "attach",
        @schema.object(issue_id => {
          path => {
            filename => {
              description => {
                notes => Attach(issue_id, path, filename, description, notes)
              }
            }
          }
        })
        |> @schema.field("issue_id", record_id())
        |> @schema.field(
          "path",
          attachment_path(
            "Local file to attach. An absolute path is recommended, because a relative one resolves against the working directory of the server process.",
          ),
        )
        |> @schema.optional(
          "filename",
          @schema.not_blank().describe(
            "Name the attachment is shown under; the last segment of `path` by default.",
          ),
        )
        |> @schema.optional("description", @schema.string())
        |> @schema.optional(
          "notes",
          @schema.string().describe(
            "Comment to add to the issue in the same history entry as the attachment.",
          ),
        )
        |> @schema.Obj::done,
      ),
    )
  }
  @schema.keyed(entries)
}

///|
fn describe_attachments(mode : Mode) -> String {
  let base = [
    "Reads Redmine attachments: `show` returns the metadata of one attachment, and `download` saves its content to a local file. \{operation_key_hint}",
    "Call `show` first to inspect `filesize` and `content_type`, since the content is never returned inline.",
    "`download` takes `path`, the destination file path to write (absolute is recommended); it never overwrites a file that already exists, and answers with the path it wrote plus the filename, content type, and size.",
    "`max_size` bounds how many bytes may be written, 500 MiB by default; pass a smaller limit when the attachment should be refused above it, reading `filesize` from `show` to choose one.",
  ].join("\n")
  match mode {
    Readonly => base
    Full =>
      base +
      "\n`attach` adds a local file to an issue: it takes `path`, the local file to send (absolute is recommended), and `issue_id`, the existing issue to add it to; `notes` adds a comment in the same history entry. To attach a file to a new issue, create the issue with `redmine_issues` first."
  }
}

///|
async fn download_attachment(
  port : &AttachmentPort,
  files : &FilePort,
  id : Int32,
  path : String,
  max_size : Int64,
) -> @mcp.ToolResult {
  let mut saved : Json? = None
  try
    port.download_attachment(id, async fn(attachment, reader) {
      let declared = attachment.filesize.to_int64()
      if declared > max_size {
        raise FileError(
          message="attachment \{id} is \{declared} bytes, which exceeds the max_size limit of \{max_size} bytes",
        )
      }
      let written = files.save(path, reader, max_size)
      saved = Some(
        (
          {
            "path": written,
            "filename": attachment.filename,
            "content_type": attachment.content_type,
            "filesize": attachment.filesize,
          } : Json),
      )
    })
  catch {
    FileError(message~) => local_failure([message])
    @redmine.Response(status~, errors~) => failure(status, errors)
    @redmine.Transport(message~) => local_failure([message])
    other => local_failure(["\{other}"])
  } noraise {
    _ => success(saved.unwrap())
  }
}

///|
async fn attach_file(
  port : &AttachmentPort,
  files : &FilePort,
  issue_id : Int32,
  path : String,
  filename : String?,
  description : String?,
  notes : String?,
) -> @mcp.ToolResult {
  let content = files.open(path) catch {
    FileError(message~) => return local_failure([message])
  }
  defer (content.close)()
  let name = filename.unwrap_or(content.filename)
  let attached = try {
    let token = port.upload_file(content.reader, content.size, name)
    port.attach_uploads(
      issue_id,
      @redmine.IssueUpdate::new(notes?, uploads=[
        @redmine.UploadToken::new(token, filename=name, description?),
      ]),
    )
  } catch {
    error => return failure_of(error)
  } noraise {
    _ => ()
  }
  ignore(attached)
  let answer : Json = {
    "issue_id": issue_id,
    "filename": name,
    "filesize": Json::number(content.size.to_double()),
  }
  success(answer)
}

///|
/// `redmine_attachments`: shows, downloads and, in `Full` mode, attaches files.
/// `download` only writes to the caller's own filesystem, so `Readonly` keeps it.
pub fn attachments_tool(
  port : &AttachmentPort,
  files : &FilePort,
  mode : Mode,
) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_attachments",
    description=describe_attachments(mode),
    input=attachment_input(mode),
    handler=async fn(action) {
      match action {
        Show(id) => respond(() => port.show_attachment(id))
        Download(id, path, max_size) =>
          download_attachment(port, files, id, path, max_size.to_int64())
        Attach(issue_id, path, filename, description, notes) =>
          attach_file(port, files, issue_id, path, filename, description, notes)
      }
    },
  )
}
