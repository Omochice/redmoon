///|
priv enum TagAction {
  Show(Int32)
  Add(Int32, Array[String])
  Remove(Int32, Array[String])
  List
  ListIssues(
    Array[String],
    project_id~ : Int32?,
    status_id~ : @issues.StatusFilter?,
    limit~ : Int32?
  )
  ListWikiPages(@redmine.ProjectRef, String)
}

///|
/// The SDK refuses the same names, but checking them here reports which item is wrong and advertises the rule in the schema.
let tag_name : @schema.Schema[String] = @schema.string().refine(
  name => !name.contains_char(',') && name.iter().any(c => !c.is_whitespace()),
  "must be a name without a comma and not blank",
  keywords=[("pattern", "^[^,]*\\S[^,]*$")],
)

///|
fn tags_input(mode : Mode) -> @schema.Schema[TagAction] {
  let issue_id = @schema.required("issue_id", record_id())
  let names = @schema.required("tags", @schema.array(tag_name, min_items=1))
  let project_id = @schema.optional("project_id", record_id())
  let status_id = @schema.optional("status_id", status_filter())
  let wiki_project_id = @schema.required("project_id", project_ref())
  let tag = @schema.required("tag", tag_name)
  let read = [
    (
      "show",
      @schema.record([issue_id.as_member()], v => {
        TagAction::Show(v.get(issue_id))
      }),
    ),
    ("list", @schema.record([], _ => TagAction::List)),
    (
      "list_issues",
      @schema.record(
        [
          names.as_member(),
          project_id.as_member(),
          status_id.as_member(),
          list_limit.as_member(),
        ],
        v => {
          TagAction::ListIssues(
            v.get(names),
            project_id=v.get(project_id),
            status_id=v.get(status_id),
            limit=v.get(list_limit),
          )
        },
      ),
    ),
    (
      "list_wiki_pages",
      @schema.record([wiki_project_id.as_member(), tag.as_member()], v => {
        TagAction::ListWikiPages(v.get(wiki_project_id), v.get(tag))
      }),
    ),
  ]
  let write = [
    (
      "add",
      @schema.record([issue_id.as_member(), names.as_member()], v => {
        TagAction::Add(v.get(issue_id), v.get(names))
      }),
    ),
    (
      "remove",
      @schema.record([issue_id.as_member(), names.as_member()], v => {
        TagAction::Remove(v.get(issue_id), v.get(names))
      }),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn tags_description(mode : Mode) -> String {
  let subject = "the tags that the Additional Tags plugin puts on Redmine issues, and find wiki pages by tag: `show` answers an issue's tag names, `list` answers every issue tag with the number of issues that carry it, `list_issues` lists the issues carrying any of the given names, and `list_wiki_pages` lists the wiki pages of one project carrying one name."
  let reads = [
    "A tag name must not contain a comma, which the plugin would split into several tags.",
    "`list_issues` takes `project_id`, `status_id`, and `limit` as `list` of `redmine_issues` does, lists only open issues unless `status_id` says otherwise, and answers issues of the same shape that carry no tags; `show` reads each issue's tags.",
    "`list` needs a Redmine administrator and answers 403 to anyone else, who can learn the names in use from `show` on related issues.",
    "`list_wiki_pages` takes `project_id` and a single `tag`, and answers pages as `list` of `redmine_wiki_pages` does; a page's own tags cannot be read.",
  ]
  let lines = match mode {
    Readonly =>
      [
        "Read \{subject}",
        ..reads,
        "Needs the Additional Tags plugin with its issue tags, and its wiki tags for `list_wiki_pages`, switched on, and the view_issue_tags permission.",
      ]
    Full =>
      [
        "Read and change \{subject}",
        "`add` and `remove` attach and detach only the names they are given, matched in any case, and answer the issue's tag names after the write; `add` should reuse a name as `show` returns it, because a name that differs from an existing tag only in case is dropped for a user without create_issue_tags.",
        ..reads,
        "Needs the Additional Tags plugin with its issue tags, and its wiki tags for `list_wiki_pages`, switched on; reading needs the view_issue_tags permission, `add` and `remove` need edit_issue_tags, and `add` of a name no issue carries yet needs create_issue_tags.",
      ]
  }
  [..lines, operation_key_hint].join("\n")
}

///|
/// `redmine_tags`: the issue tags of the Additional Tags plugin, and the wiki pages found by tag.
/// `Readonly` mode leaves out `add` and `remove`.
pub fn tags_tool(port : &TagPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="redmine_tags",
    description=tags_description(mode),
    input=tags_input(mode),
    handler=async fn(action) {
      match action {
        Show(issue_id) => respond(() => port.issue_tags(issue_id))
        Add(issue_id, names) =>
          respond(() => port.add_issue_tags(issue_id, names))
        Remove(issue_id, names) =>
          respond(() => port.remove_issue_tags(issue_id, names))
        List => respond(() => port.list_issue_tags())
        ListIssues(names, project_id~, status_id~, limit~) =>
          respond(() => {
            port.list_tagged_issues(names, project_id, status_id, limit)
          })
        ListWikiPages(project, name) =>
          respond(() => port.list_tagged_wiki_pages(project, name))
      }
    },
  )
}
