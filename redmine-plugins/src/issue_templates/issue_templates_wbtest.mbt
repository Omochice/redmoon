///|
test "a list_templates response decodes without its tracker_name, whose type differs per kind" {
  let json = @json.parse(
    (
      #|{"global_issue_templates":[{"id":1,"tracker_id":1,"tracker_name":1,"title":"Global bug report","description":"Global steps to reproduce:\n","enabled":true,"updated_on":"2026-10-18T08:20:14Z","created_on":"2026-10-18T08:20:14Z"}],"inherit_templates":[],"issue_templates":[{"id":1,"tracker_id":1,"tracker_name":"Bug","title":"Bug report","issue_title":"[Bug] ","description":"Steps to reproduce:\n","enabled":true,"is_default":false,"enabled_sharing":false,"position":1,"updated_on":"2026-10-18T08:20:14Z","created_on":"2026-10-18T08:20:14Z"}]}
    ),
  )
  let templates : Templates = @decode.decode(json) catch { _ => fail("decode") }
  assert_eq(templates.global, [
    {
      id: 1,
      tracker_id: 1,
      title: "Global bug report",
      issue_title: None,
      description: "Global steps to reproduce:\n",
      note: None,
      enabled: true,
      created_on: "2026-10-18T08:20:14Z",
      updated_on: "2026-10-18T08:20:14Z",
    },
  ])
  assert_eq(templates.inherited, [])
  assert_eq(templates.project, [
    {
      id: 1,
      tracker_id: 1,
      title: "Bug report",
      issue_title: Some("[Bug] "),
      description: "Steps to reproduce:\n",
      note: None,
      enabled: true,
      is_default: false,
      enabled_sharing: false,
      position: 1,
      created_on: "2026-10-18T08:20:14Z",
      updated_on: "2026-10-18T08:20:14Z",
    },
  ])
}

///|
test "templates encode under the plugin's keys" {
  let templates : Templates = { global: [], inherited: [], project: [], }
  assert_eq(
    templates.to_json().stringify(),
    "{\"global_issue_templates\":[],\"inherit_templates\":[],\"issue_templates\":[]}",
  )
}

///|
test "a response without the template arrays fails to decode" {
  try @json.from_json(Json::object({})) catch {
    _ => ()
  } noraise {
    (_ : Templates) => fail("expected a decode error")
  }
}
