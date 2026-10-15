///|
struct VersionCreate {
  project_id : Int
  name : String
  description : String
  status : String?
  sharing : String
  notes : Array[String]
} derive(Debug)

///|
let version_create : Schema[VersionCreate] = object(
  project_id => name => description => status => sharing => notes => {
    project_id,
    name,
    description,
    status,
    sharing,
    notes,
  },
)
  |> field("project_id", integer(min=1))
  |> field("name", string(min_length=1))
  |> field("description", string().describe("Free text"))
  |> optional("status", picklist(["open", "locked", "closed"]))
  |> optional_or("sharing", picklist(["none", "system"]), "none")
  |> optional_or("notes", array(string()), [])
  |> Obj::done

///|
test "object emits a strict schema" {
  assert_eq(
    schema_json(version_create),
    "{\"type\":\"object\",\"properties\":{\"project_id\":{\"type\":\"integer\",\"minimum\":1},\"name\":{\"type\":\"string\",\"minLength\":1},\"description\":{\"type\":\"string\",\"description\":\"Free text\"},\"status\":{\"type\":\"string\",\"enum\":[\"open\",\"locked\",\"closed\"]},\"sharing\":{\"type\":\"string\",\"enum\":[\"none\",\"system\"],\"default\":\"none\"},\"notes\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"default\":[]}},\"required\":[\"project_id\",\"name\",\"description\"],\"additionalProperties\":false}",
  )
}

///|
test "object without required fields omits required" {
  let s = object(a => a)|> optional("a", boolean()) |> Obj::done
  assert_eq(
    schema_json(s),
    "{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"boolean\"}},\"additionalProperties\":false}",
  )
  let empty = object(0) |> Obj::done
  assert_eq(
    schema_json(empty),
    "{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}",
  )
}

///|
test "object parses every field to its own parameter" {
  let parsed = version_create.parse(
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
test "absent optional fields are None and defaults" {
  let parsed = version_create.parse(
    j("{\"project_id\":1,\"name\":\"n\",\"description\":\"\"}"),
  )
  assert_eq(parsed.status, None)
  assert_eq(parsed.sharing, "none")
  assert_eq(parsed.notes, [])
}

///|
test "object errors name the field" {
  let ok = "\"name\":\"n\",\"description\":\"\""
  assert_eq(
    outcome(version_create, "{" + ok + "}"),
    "error: project_id: is required",
  )
  assert_eq(
    outcome(version_create, "{\"project_id\":0," + ok + "}"),
    "error: project_id: must be at least 1",
  )
  assert_eq(
    outcome(version_create, "{\"project_id\":1," + ok + ",\"status\":\"x\"}"),
    "error: status: must be one of open, locked, closed",
  )
  assert_eq(
    outcome(version_create, "{\"project_id\":1," + ok + ",\"notes\":[\"a\",2]}"),
    "error: notes.1: expected a string",
  )
  assert_eq(
    outcome(version_create, "{\"project_id\":1,\"name\":\"\",\"description\":\"\"}"),
    "error: name: must be at least 1 characters",
  )
  assert_eq(outcome(version_create, "[]"), "error: expected an object")
  assert_eq(
    outcome(version_create, "{\"project_id\":1," + ok + ",\"status\":null}"),
    "error: status: must be one of open, locked, closed",
  )
}

///|
test "unknown keys are rejected" {
  let ok = "\"project_id\":1,\"name\":\"n\",\"description\":\"\""
  assert_eq(
    outcome(version_create, "{" + ok + ",\"extra\":1}"),
    "error: extra: unknown field",
  )
  assert_eq(
    outcome(version_create, "{" + ok + ",\"projectId\":1,\"other\":2}"),
    "error: projectId: unknown field; other: unknown field",
  )
}

///|
test "errors are prefixed by the caller's path" {
  let result = try
    version_create.parse_at(j("{\"extra\":1}"), ["create"])
  catch {
    e => e.message()
  } noraise {
    _ => "ok"
  }
  assert_eq(result, "create.extra: unknown field")
}

///|
test "nested objects report dotted paths" {
  let inner = object(n => n)|> field("n", integer()) |> Obj::done
  let outer = object(i => i)|> field("inner", inner) |> Obj::done
  assert_eq(outcome(outer, "{\"inner\":{\"n\":\"x\"}}"), "error: inner.n: expected an integer")
  assert_eq(outcome(outer, "{\"inner\":{}}"), "error: inner.n: is required")
  assert_eq(outcome(outer, "{\"inner\":{\"n\":1}}"), "ok: 1")
}
