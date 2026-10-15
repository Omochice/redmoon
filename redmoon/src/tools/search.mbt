///|
fn attachment_scope_schema() -> @schema.Schema[@redmine.AttachmentScope] {
  @schema.union([
    @schema.boolean().map(included => {
      if included {
        @redmine.AttachmentScope::Included
      } else {
        @redmine.AttachmentScope::Excluded
      }
    }),
    @schema.literal("only").map(_ => @redmine.AttachmentScope::Only),
  ])
}

///|
fn search_input() -> @schema.Schema[@redmine.SearchQuery] {
  @schema.object(q => {
    scope => {
      all_words => {
        titles_only => {
          open_issues => {
            issues => {
              news => {
                documents => {
                  changesets => {
                    wiki_pages => {
                      messages => {
                        projects => {
                          attachments => @redmine.SearchQuery::{
                            q,
                            scope,
                            all_words,
                            titles_only,
                            open_issues,
                            issues,
                            news,
                            documents,
                            changesets,
                            wiki_pages,
                            messages,
                            projects,
                            attachments,
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  })
  |> @schema.field("q", @schema.string())
  |> @schema.optional("scope", @schema.string())
  |> @schema.optional("all_words", @schema.boolean())
  |> @schema.optional("titles_only", @schema.boolean())
  |> @schema.optional("open_issues", @schema.boolean())
  |> @schema.optional("issues", @schema.boolean())
  |> @schema.optional("news", @schema.boolean())
  |> @schema.optional("documents", @schema.boolean())
  |> @schema.optional("changesets", @schema.boolean())
  |> @schema.optional("wiki_pages", @schema.boolean())
  |> @schema.optional("messages", @schema.boolean())
  |> @schema.optional("projects", @schema.boolean())
  |> @schema.optional("attachments", attachment_scope_schema())
  |> @schema.Obj::done
}

///|
fn search_result_json(result : @redmine.SearchResult) -> Json {
  let description : Json = match result.description {
    Some(text) => Json(text)
    None => Json::null()
  }
  {
    "id": result.id,
    "title": result.title,
    "type": result.kind,
    "url": result.url,
    "description": description,
    "datetime": result.datetime,
  }
}

///|
/// `redmine_search`: full-text search across the resources Redmine indexes.
pub fn search_tool(port : &SearchPort) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_search",
    description="Full-text search across Redmine issues, wiki pages, news, documents, changesets, messages, and projects.\nRequires `q`; narrow with `scope` and the per-resource flags.\nPass the arguments under the single key `search`: `{\"search\": {\"q\": \"login\"}}`.",
    input=@schema.keyed([("search", search_input())]),
    handler=async fn(query) {
      respond(() => Json::array(port.search(query).map(search_result_json)))
    },
  )
}
