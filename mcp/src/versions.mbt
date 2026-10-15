///|
let modern_versions : Array[String] = ["2026-07-28"]

///|
let legacy_versions : Array[String] = [
  "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05",
]

///|
let fallback_legacy_version : String = "2025-11-25"

///|
let version_key : String = "io.modelcontextprotocol/protocolVersion"

///|
let capabilities_key : String = "io.modelcontextprotocol/clientCapabilities"

///|
let server_info_key : String = "io.modelcontextprotocol/serverInfo"

///|
fn supported_versions() -> Array[String] {
  [..modern_versions, ..legacy_versions]
}

///|
/// The wire shape a result takes; the two eras differ in `resultType` and in
/// where the server identifies itself.
priv enum Era {
  Legacy
  Modern
}

///|
fn invalid_params(message : String) -> RpcError {
  RpcError::new(invalid_params_code, message)
}

///|
fn unsupported_version(requested : String) -> RpcError {
  RpcError::new(
    unsupported_version_code,
    "Unsupported protocol version",
    data=object([
      ("supported", Json::array(supported_versions().map(v => Json(v)))),
      ("requested", Json(requested)),
    ]),
  )
}

///|
fn meta_of(params : Map[String, Json]) -> Map[String, Json] {
  match params.get("_meta") {
    Some(Object(meta)) => meta
    _ => Map([])
  }
}

///|
/// Decides which era serves a request: a version in the request's `_meta` wins,
/// otherwise the version an earlier `initialize` negotiated applies.
fn resolve_era(
  params : Map[String, Json],
  negotiated : String?,
) -> Result[Era, RpcError] {
  let meta = meta_of(params)
  match meta.get(version_key) {
    Some(String(version)) =>
      if modern_versions.contains(version) {
        if meta.get(capabilities_key) is Some(Object(_)) {
          Ok(Modern)
        } else {
          Err(invalid_params("`_meta.\{capabilities_key}` is required"))
        }
      } else if legacy_versions.contains(version) {
        Ok(Legacy)
      } else {
        Err(unsupported_version(version))
      }
    Some(_) => Err(invalid_params("`_meta.\{version_key}` must be a string"))
    None =>
      if negotiated is Some(_) {
        Ok(Legacy)
      } else {
        Err(
          invalid_params(
            "`_meta.\{version_key}` is required before `initialize` has been called",
          ),
        )
      }
  }
}
