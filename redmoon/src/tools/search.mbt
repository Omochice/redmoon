///|
fn attachment_scope_schema() -> @schema.Schema[@search.AttachmentScope] {
  @schema.union([
    @schema.boolean().map(included => {
      if included {
        @search.AttachmentScope::Included
      } else {
        @search.AttachmentScope::Excluded
      }
    }),
    @schema.literal("only").map(_ => @search.AttachmentScope::Only),
  ])
}

///|
fn search_input() -> @schema.Schema[@search.Query] {
  let q = @schema.required("q", @schema.string())
  let scope = @schema.optional(
    "scope",
    @schema.string().describe(
      "Projects to search: `all`, `my_projects` (the ones the caller is a member of), or `bookmarks` (the ones the caller bookmarked); every project when left out.",
    ),
  )
  let all_words = @schema.optional("all_words", @schema.boolean())
  let titles_only = @schema.optional("titles_only", @schema.boolean())
  let open_issues = @schema.optional("open_issues", @schema.boolean())
  let issues = @schema.optional("issues", @schema.boolean())
  let news = @schema.optional("news", @schema.boolean())
  let documents = @schema.optional("documents", @schema.boolean())
  let changesets = @schema.optional("changesets", @schema.boolean())
  let wiki_pages = @schema.optional("wiki_pages", @schema.boolean())
  let messages = @schema.optional("messages", @schema.boolean())
  let projects = @schema.optional("projects", @schema.boolean())
  let attachments = @schema.optional("attachments", attachment_scope_schema())
  @schema.record(
    [
      q.as_member(),
      scope.as_member(),
      all_words.as_member(),
      titles_only.as_member(),
      open_issues.as_member(),
      issues.as_member(),
      news.as_member(),
      documents.as_member(),
      changesets.as_member(),
      wiki_pages.as_member(),
      messages.as_member(),
      projects.as_member(),
      attachments.as_member(),
    ],
    v => {
      @search.Query::new(
        q=v.get(q),
        scope?=v.get(scope),
        all_words?=v.get(all_words),
        titles_only?=v.get(titles_only),
        open_issues?=v.get(open_issues),
        issues?=v.get(issues),
        news?=v.get(news),
        documents?=v.get(documents),
        changesets?=v.get(changesets),
        wiki_pages?=v.get(wiki_pages),
        messages?=v.get(messages),
        projects?=v.get(projects),
        attachments?=v.get(attachments),
      )
    },
  )
}

///|
/// The tool output has always written an absent description as `null`, while the SDK leaves an absent field out,
/// so the match is spelled here rather than encoded by the SDK.
fn match_json(found : @search.Match) -> Json {
  {
    "id": found.id,
    "title": found.title,
    "type": found.kind,
    "url": found.url,
    "description": found.description.map(Json::string).unwrap_or(Json::null()),
    "datetime": found.datetime,
  }
}

///|
/// `redmine_search`: full-text search across the resources Redmine indexes.
pub fn search_tool(port : &SearchPort) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_search",
    description=describe_tool([
      "Full-text search across Redmine issues, wiki pages, news, documents, changesets, messages, and projects.",
      "Requires `q`; narrow with `scope` and the per-resource flags.",
    ]),
    input=@schema.keyed([("search", search_input())]),
    handler=async fn(query) {
      respond(() => port.search(query).map(match_json))
    },
  )
}
