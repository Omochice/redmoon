///|
/// The value of a custom field: one string, or several for a multi-value field.
#derive(Eq, Debug)
pub(all) enum CustomFieldValue {
  Single(String)
  Multiple(Array[String])
}

///|
pub extend CustomFieldValue with Eq::{equal, not_equal}

///|
pub extend CustomFieldValue with @debug.Debug::{to_repr}

///|
pub extend CustomFieldValue with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for CustomFieldValue with fn from_json(json, path) {
  match json {
    String(value) => Single(value)
    Array(_) => Multiple(@json.from_json(json, path~))
    _ =>
      raise @json.JsonDecodeError(
        (path, "CustomFieldValue::from_json: expected string or array"),
      )
  }
}

///|
pub extend CustomFieldValue with ToJson::{to_json}

///|
pub impl ToJson for CustomFieldValue with fn to_json(self) {
  match self {
    Single(value) => Json(value)
    Multiple(values) => Json(values)
  }
}
