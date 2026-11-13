///|
async test "an added tag is shown, listed, and found, and removing it leaves the issue untagged" {
  let redmine = @livetest.redmine()
  let id = @livetest.create_probe_issue(redmine, "additional tags round trip")
  defer @livetest.delete_probe_issue(redmine, id)
  let added = redmine |> @additional_tags.add(id, ["  Redmoon-Probe-Round  "])
  assert_eq(added, ["Redmoon-Probe-Round"])
  assert_eq(redmine |> @additional_tags.tags(id), ["Redmoon-Probe-Round"])
  let catalogue = redmine |> @additional_tags.list()
  assert_true(
    catalogue.any(tag => tag.name == "Redmoon-Probe-Round" && tag.count == 1),
  )
  let found = redmine |> @additional_tags.list_issues(["redmoon-probe-round"])
  assert_eq(found.map(issue => issue.id), [id])
  let removed = redmine |> @additional_tags.remove(id, ["REDMOON-PROBE-ROUND"])
  assert_eq(removed, [])
}

///|
async test "adding a tag the issue carries in another case keeps the issue's spelling" {
  let redmine = @livetest.redmine()
  let id = @livetest.create_probe_issue(redmine, "additional tags case")
  defer @livetest.delete_probe_issue(redmine, id)
  ignore(redmine |> @additional_tags.add(id, ["redmoon-probe-case"]))
  let again = redmine
    |> @additional_tags.add(id, ["REDMOON-PROBE-CASE", "redmoon-probe-other"])
  assert_eq(again, ["redmoon-probe-case", "redmoon-probe-other"])
}

///|
async test "list_issues leaves closed issues out unless asked for them" {
  let redmine = @livetest.redmine()
  let id = @livetest.create_probe_issue(redmine, "additional tags closed")
  defer @livetest.delete_probe_issue(redmine, id)
  ignore(redmine |> @additional_tags.add(id, ["redmoon-probe-closed"]))
  ignore(
    @redmine.send(redmine, Put, ["issues", "\{id}.json"], body={
      "issue": { "status_id": 5 },
    }),
  )
  assert_eq(redmine |> @additional_tags.list_issues(["redmoon-probe-closed"]), [])
  let closed = redmine
    |> @additional_tags.list_issues(["redmoon-probe-closed"], status_id=Closed)
  assert_eq(closed.map(issue => issue.id), [id])
}

///|
async test "a member may attach an existing tag but a new one is reported as unsaved" {
  let redmine = @livetest.redmine()
  let colleague = @livetest.as_member()
  let holder = @livetest.create_probe_issue(redmine, "additional tags holder")
  defer @livetest.delete_probe_issue(redmine, holder)
  let target = @livetest.create_probe_issue(redmine, "additional tags target")
  defer @livetest.delete_probe_issue(redmine, target)
  ignore(redmine |> @additional_tags.add(holder, ["redmoon-probe-shared"]))
  assert_eq(
    colleague |> @additional_tags.add(target, ["redmoon-probe-shared"]),
    ["redmoon-probe-shared"],
  )
  try
    colleague |> @additional_tags.add(target, ["redmoon-probe-brand-new"])
  catch {
    Decode(message~) =>
      assert_true(message.contains("`redmoon-probe-brand-new`"))
    _ => fail("expected Decode")
  } noraise {
    _ => fail("expected the dropped write to be reported")
  }
  assert_eq(redmine |> @additional_tags.tags(target), ["redmoon-probe-shared"])
}

///|
async test "a member is told that the tag list needs an administrator" {
  let colleague = @livetest.as_member()
  try colleague |> @additional_tags.list() catch {
    Response(status~, errors~) => {
      assert_eq(status, 403)
      assert_eq(errors.length(), 1)
      assert_true(errors[0].contains("administrator"))
    }
    _ => fail("expected Response")
  } noraise {
    _ => fail("expected a 403")
  }
}

///|
async test "a member who may create tags adds a name no issue carries yet" {
  let redmine = @livetest.redmine()
  let tagger = @livetest.as_tagger()
  let id = @livetest.create_probe_issue(redmine, "additional tags create")
  defer @livetest.delete_probe_issue(redmine, id)
  assert_eq(tagger |> @additional_tags.add(id, ["redmoon-probe-created"]), [
    "redmoon-probe-created",
  ])
  assert_eq(redmine |> @additional_tags.tags(id), ["redmoon-probe-created"])
}

///|
/// The SDK cannot write wiki tags, so the page is tagged by a request built here.
/// Redmine refuses `tag_list` without the page text, so the request carries both.
async test "a tagged wiki page is found by its tag in any case, by an administrator and by a member" {
  let redmine = @livetest.redmine()
  let title = "Redmoon_probe_wiki_tag_\{@async.now()}"
  let page = ["projects", "demo", "wiki", "\{title}.json"]
  ignore(
    @redmine.send(redmine, Put, page, body={
      "wiki_page": { "text": "probe", "tag_list": ["redmoon-probe-wiki"] },
    }),
  )
  defer @livetest.cleanup(() => ignore(@redmine.send(redmine, Delete, page)))
  let found = redmine
    |> @additional_tags.list_wiki_pages(
      Identifier("demo"),
      "REDMOON-PROBE-WIKI",
    )
  assert_eq(found.map(page => page.title), [title])
  let colleague = @livetest.as_member()
  let seen = colleague
    |> @additional_tags.list_wiki_pages(
      Identifier("demo"),
      "redmoon-probe-wiki",
    )
  assert_eq(seen.map(page => page.title), [title])
  assert_eq(
    redmine
    |> @additional_tags.list_wiki_pages(
      Identifier("demo"),
      "redmoon-probe-wiki-nobody",
    ),
    [],
  )
}
