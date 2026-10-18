///|
/// Decodes `json` into `T`, reporting a shape mismatch as `Transport`.
pub fn[T : @json.FromJson] decode(json : Json) -> T raise @redmine.RedmineError {
  @json.from_json(json) catch {
    error =>
      raise @redmine.Transport(message="unexpected response shape: \{error}")
  }
}
