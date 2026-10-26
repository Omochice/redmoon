///|
/// The RedmineUP Agile plugin's row for one issue: its story points, its sprint, and its place on the board.
/// `id` names the row itself, not the issue.
pub(all) struct AgileData {
  id : Int32
  issue_id : Int32
  story_points : Int32?
  agile_sprint_id : Int32?
  position : Int32?
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend AgileData with @json.FromJson::{from_json}

///|
pub extend AgileData with ToJson::{to_json}

///|
pub extend AgileData with Eq::{equal, not_equal}

///|
pub extend AgileData with @debug.Debug::{to_repr}

///|
/// Changes to an issue's agile data; an unset field keeps the value it has.
/// `Clear` empties a field, which for `agile_sprint_id` takes the issue out of its sprint.
pub(all) struct Update {
  story_points : @redmine.Clearable[Int32]?
  agile_sprint_id : @redmine.Clearable[Int32]?
  position : @redmine.Clearable[Int32]?
} derive(Eq, Debug)

///|
pub extend Update with Eq::{equal, not_equal}

///|
pub extend Update with @debug.Debug::{to_repr}

///|
/// The changes to apply to an issue's agile data; only the fields given are touched.
///
/// ```mbt check
/// test {
///   let update = @agile.Update::new(story_points=Set(3), agile_sprint_id=Clear)
///   assert_eq(update.story_points, Some(@redmine.Clearable::Set(3)))
///   assert_eq(update.agile_sprint_id, Some(@redmine.Clearable::Clear))
///   assert_true(update.position is None)
/// }
/// ```
pub fn Update::new(
  story_points? : @redmine.Clearable[Int32],
  agile_sprint_id? : @redmine.Clearable[Int32],
  position? : @redmine.Clearable[Int32],
) -> Update {
  { story_points, agile_sprint_id, position, }
}

///|
/// The plugin accepts the nested attributes without `update_only`, so a payload without the row's `id` replaces the row and nulls every field it leaves out.
/// Carrying the current row forward is what makes the write a change instead of a replacement.
fn Update::to_body(self : Update, current : AgileData?) -> Json {
  let attributes : Map[String, Json] = Map([])
  if current is Some(row) {
    attributes["id"] = Json(row.id)
  }
  let put = fn(
    name : String,
    change : @redmine.Clearable[Int32]?,
    held : Int32?,
  ) {
    match (change, held) {
      (Some(Set(value)), _) | (None, Some(value)) =>
        attributes[name] = Json(value)
      (Some(Clear), _) => attributes[name] = Json::null()
      (None, None) => ()
    }
  }
  put("story_points", self.story_points, current.bind(row => row.story_points))
  put(
    "agile_sprint_id",
    self.agile_sprint_id,
    current.bind(row => row.agile_sprint_id),
  )
  put("position", self.position, current.bind(row => row.position))
  { "issue": { "agile_data_attributes": Json::object(attributes) } }
}

///|
async fn[T] or_missing(
  read : async () -> T raise @redmine.RedmineError,
) -> T? raise @redmine.RedmineError {
  Some(read()) catch {
    Response(status=404, ..) => None
    error => raise error
  }
}

///|
/// The agile data of the issue `issue_id`.
/// Raises `RedmineError` on a non-2xx answer or a transport failure.
/// The answer is 404 for an issue without agile data and on an instance without the plugin, and 403 when the project lacks the Agile module or the user may not `view_agile_queries`.
///
/// ```mbt check
/// #skip("needs a live Redmine with the RedmineUP Agile plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let agile_data = redmine |> @agile.get(42)
///   ignore(agile_data)
/// }
/// ```
pub async fn get(
  redmine : @redmine.Redmine,
  issue_id : Int32,
) -> AgileData raise @redmine.RedmineError {
  let json = redmine
    |> @redmine.send(Get, ["issues", issue_id.to_string(), "agile_data.json"])
  @decode.decode_field(json, "agile_data")
}

///|
/// Changes the agile data of the issue `issue_id`, keeping every field `attributes` leaves unset.
/// An issue without agile data gets a row holding only the fields given.
/// Raises `RedmineError` on a non-2xx answer or a transport failure, without writing anything when the current agile data cannot be read for any reason other than a 404.
///
/// ```mbt check
/// #skip("needs a live Redmine with the RedmineUP Agile plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   redmine |> @agile.update(42, @agile.Update::new(story_points=Set(3)))
/// }
/// ```
pub async fn update(
  redmine : @redmine.Redmine,
  issue_id : Int32,
  attributes : Update,
) -> Unit raise @redmine.RedmineError {
  let current = or_missing(() => get(redmine, issue_id))
  ignore(
    redmine
    |> @redmine.send(
      Put,
      ["issues", issue_id.to_string() + ".json"],
      body=attributes.to_body(current),
    ),
  )
}
