///|
/// The release version, read from `version.json` which release-please bumps.
pub let version : String = parse_version(version_json)

///|
fn parse_version(source : String) -> String {
  let parsed = @json.parse(source) catch {
    error => abort("version.json is not valid JSON: \{error}")
  }
  match parsed {
    Object(fields) =>
      match fields.get("version") {
        Some(String(value)) => value
        _ => abort("version.json has no string \"version\" field")
      }
    _ => abort("version.json is not a JSON object")
  }
}
