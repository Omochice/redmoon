///|
/// The plugin splits a name at commas, so no page can carry this one.
/// Only an index that ignores `tag` answers a page for it.
const NO_TAG_CAN_MATCH : String = "redmoon,none"

///|
const WIKI_TAGS_IGNORED : String = "Redmine listed wiki pages for a tag no page can carry, so it ignored the tag; the Additional Tags plugin is not installed or its wiki tags are switched off"

///|
/// Redmine answers every page when the plugin does not filter, which would otherwise read as every page carrying `name`.
async fn search_wiki_pages(
  name : String,
  list~ : async (String) -> Array[@wiki.PageSummary] raise @redmine.RedmineError,
) -> Array[@wiki.PageSummary] raise @redmine.RedmineError {
  let name = validate([name])[0]
  guard list(NO_TAG_CAN_MATCH).is_empty() else {
    raise @redmine.Decode(message=WIKI_TAGS_IGNORED)
  }
  list(name)
}

///|
/// The wiki pages of `project` carrying the tag `name`, matched in any case.
/// Raises `InvalidArgument` before any request when `name` is blank or contains a comma.
/// Raises `Decode` when Redmine ignored the tag because the Additional Tags plugin is not installed or its wiki tags are switched off.
/// Raises `RedmineError` on a non-2xx answer, an unreadable 2xx answer, or a transport failure.
///
/// ```mbt check
/// #skip("needs a live Redmine with the Additional Tags plugin")
/// async test {
///   let redmine = @redmine.new(
///     endpoint="https://redmine.example.com",
///     api_key="...",
///   )
///   let pages = redmine
///     |> @additional_tags.list_wiki_pages(Identifier("demo"), "howto")
///   ignore(pages)
/// }
/// ```
pub async fn list_wiki_pages(
  redmine : @redmine.Redmine,
  project : @redmine.ProjectRef,
  name : String,
) -> Array[@wiki.PageSummary] raise @redmine.RedmineError {
  search_wiki_pages(name, list=tag => {
    let json = redmine
      |> @redmine.send(
        Get,
        ["projects", project.segment(), "wiki", "index.json"],
        query=[("tag", tag)],
      )
    @decode.decode_field(json, "wiki_pages")
  })
}
