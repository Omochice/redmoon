///|
/// The Redmine operations behind `redmine_attachments`.
pub(open) trait AttachmentPort {
  async fn show_attachment(Self, Int32) -> @redmine.Attachment raise @redmine.RedmineError
  /// Raises plain errors because the consumer's own failures pass through it.
  async fn download_attachment(
    Self,
    Int32,
    async (@redmine.Attachment, &@io.Reader) -> Unit,
  ) -> Unit
  async fn upload_file(Self, &@io.Reader, Int64, String) -> String raise @redmine.RedmineError
  async fn attach_uploads(Self, Int32, @redmine.IssueUpdate) -> Unit raise @redmine.RedmineError
}

///|
pub impl AttachmentPort for @redmine.Redmine with fn show_attachment(self, id) {
  self.show_attachment(id)
}

///|
pub impl AttachmentPort for @redmine.Redmine with fn download_attachment(
  self,
  id,
  consume,
) {
  self.download_attachment(id, consume)
}

///|
pub impl AttachmentPort for @redmine.Redmine with fn upload_file(
  self,
  reader,
  size,
  filename,
) {
  self.upload(reader, size, filename~)
}

///|
pub impl AttachmentPort for @redmine.Redmine with fn attach_uploads(
  self,
  issue_id,
  update,
) {
  self.update_issue(issue_id, update)
}
