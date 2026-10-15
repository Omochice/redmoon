///|
struct VersionRecord {
  project_id : Int32
  name : String
  description : String
  status : String?
  sharing : String
  notes : Array[String]
} derive(Debug)

///|
let r_project_id : @schema.Field[Int32] = @schema.required(
  "project_id",
  integer(min=1),
)

///|
let r_name : @schema.Field[String] = @schema.required(
  "name",
  string(min_length=1),
)

///|
let r_description : @schema.Field[String] = @schema.required(
  "description",
  string().describe("Free text"),
)

///|
let r_status : @schema.Field[String?] = @schema.optional_field(
  "status",
  picklist(["open", "locked", "closed"]),
)

///|
let r_sharing : @schema.Field[String] = @schema.optional_or_field(
  "sharing",
  picklist(["none", "system"]),
  "none",
)

///|
let r_notes : @schema.Field[Array[String]] = @schema.optional_or_field(
  "notes",
  array(string()),
  [],
)

///|
let version_record : Schema[VersionRecord] = @schema.record(
  [
    r_project_id.as_member(),
    r_name.as_member(),
    r_description.as_member(),
    r_status.as_member(),
    r_sharing.as_member(),
    r_notes.as_member(),
  ],
  v => {
    project_id: v.get(r_project_id),
    name: v.get(r_name),
    description: v.get(r_description),
    status: v.get(r_status),
    sharing: v.get(r_sharing),
    notes: v.get(r_notes),
  },
)

///|
test "record emits a strict schema" {
  assert_eq(
    schema_json(version_record),
    "{\"type\":\"object\",\"properties\":{\"project_id\":{\"type\":\"integer\",\"minimum\":1},\"name\":{\"type\":\"string\",\"minLength\":1},\"description\":{\"type\":\"string\",\"description\":\"Free text\"},\"status\":{\"type\":\"string\",\"enum\":[\"open\",\"locked\",\"closed\"]},\"sharing\":{\"type\":\"string\",\"enum\":[\"none\",\"system\"],\"default\":\"none\"},\"notes\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"default\":[]}},\"required\":[\"project_id\",\"name\",\"description\"],\"additionalProperties\":false}",
  )
}

///|
test "record without required members omits required" {
  let a = @schema.optional_field("a", boolean())
  let s = @schema.record([a.as_member()], v => v.get(a))
  assert_eq(
    schema_json(s),
    "{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"boolean\"}},\"additionalProperties\":false}",
  )
  let empty = @schema.record([], _ => 0)
  assert_eq(
    schema_json(empty),
    "{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}",
  )
}

///|
test "record reads every member by its handle" {
  let parsed = version_record.parse(
    j(
      "{\"project_id\":7,\"name\":\"v1\",\"description\":\"d\",\"status\":\"open\",\"sharing\":\"system\",\"notes\":[\"x\",\"y\"]}",
    ),
  )
  assert_eq(parsed.project_id, 7)
  assert_eq(parsed.name, "v1")
  assert_eq(parsed.description, "d")
  assert_eq(parsed.status, Some("open"))
  assert_eq(parsed.sharing, "system")
  assert_eq(parsed.notes, ["x", "y"])
}

///|
test "absent optional members are None and defaults" {
  let parsed = version_record.parse(
    j("{\"project_id\":1,\"name\":\"n\",\"description\":\"\"}"),
  )
  assert_eq(parsed.status, None)
  assert_eq(parsed.sharing, "none")
  assert_eq(parsed.notes, [])
}

///|
test "record errors name the member" {
  let ok = "\"name\":\"n\",\"description\":\"\""
  assert_eq(
    outcome(version_record, "{" + ok + "}"),
    "error: project_id: is required",
  )
  assert_eq(
    outcome(version_record, "{\"project_id\":0," + ok + "}"),
    "error: project_id: must be at least 1",
  )
  assert_eq(
    outcome(version_record, "{\"project_id\":1," + ok + ",\"status\":\"x\"}"),
    "error: status: must be one of open, locked, closed",
  )
  assert_eq(
    outcome(version_record, "{\"project_id\":1," + ok + ",\"notes\":[\"a\",2]}"),
    "error: notes.1: expected a string",
  )
  assert_eq(outcome(version_record, "[]"), "error: expected an object")
}

///|
test "record reports every failing member, but unknown keys alone" {
  assert_eq(
    outcome(
      version_record, "{\"project_id\":0,\"name\":\"\",\"description\":\"\"}",
    ),
    "error: project_id: must be at least 1; name: must be at least 1 characters",
  )
  let ok = "\"project_id\":1,\"name\":\"n\",\"description\":\"\""
  assert_eq(
    outcome(version_record, "{" + ok + ",\"projectId\":1,\"other\":2}"),
    "error: projectId: unknown field; other: unknown field",
  )
  assert_eq(
    outcome(version_record, "{\"project_id\":0,\"name\":\"n\",\"extra\":1}"),
    "error: extra: unknown field",
  )
}

///|
test "record errors are prefixed by the caller's path" {
  let result = try
    version_record.parse_at(j("{\"extra\":1}"), ["create"])
  catch {
    e => e.message()
  } noraise {
    _ => "ok"
  }
  assert_eq(result, "create.extra: unknown field")
}

///|
test "a field that is read but not listed raises" {
  let listed = @schema.required("listed", integer())
  let unlisted = @schema.required("unlisted", integer())
  let s = @schema.record([listed.as_member()], v => v.get(unlisted))
  assert_eq(
    outcome(s, "{\"listed\":1}"),
    "error: unlisted is not a member of the record",
  )
}

///|
test "nested records report dotted paths" {
  let n = @schema.required("n", integer())
  let inner = @schema.record([n.as_member()], v => v.get(n))
  let i = @schema.required("inner", inner)
  let outer = @schema.record([i.as_member()], v => v.get(i))
  assert_eq(
    outcome(outer, "{\"inner\":{\"n\":\"x\"}}"),
    "error: inner.n: expected an integer",
  )
  assert_eq(outcome(outer, "{\"inner\":{}}"), "error: inner.n: is required")
  assert_eq(outcome(outer, "{\"inner\":{\"n\":1}}"), "ok: 1")
}
