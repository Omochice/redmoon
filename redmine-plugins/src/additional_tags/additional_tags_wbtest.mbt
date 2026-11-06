///|
/// A record's tags as a fake read and write see them, with every write it received.
/// `saves` set to false stands for the plugin dropping `tag_list` while still answering 204.
priv struct FakeRecord {
  stored : Array[String]
  writes : Array[Array[String]]
  mut reads : Int32
  saves : Bool
}

///|
fn FakeRecord::new(stored : Array[String], saves~ : Bool = true) -> FakeRecord {
  { stored, writes: [], reads: 0, saves, }
}

///|
async fn FakeRecord::change(
  self : FakeRecord,
  change : Change,
  names : Array[String],
) -> Array[String] raise @redmine.RedmineError {
  change.apply(
    names,
    read=() => {
      self.reads += 1
      self.stored.copy()
    },
    write=next => {
      self.writes.push(next)
      if self.saves {
        self.stored.clear()
        self.stored.append(next)
      }
    },
    causes="the fake dropped it",
  )
}

///|
fn message_of(error : @redmine.RedmineError) -> String {
  match error {
    Decode(message~) | Transport(message~) | InvalidArgument(message~) =>
      message
    Response(status~, errors~) => "\{status}: \{errors.join(", ")}"
  }
}

///|
test "names are trimmed as the plugin trims them" {
  let names = validate(["  alpha ", "Beta Tag"]) catch {
    error => fail(message_of(error))
  }
  assert_eq(names, ["alpha", "Beta Tag"])
}

///|
test "no names, a blank name, or a name with a comma is refused" {
  let cases : Array[(Array[String], String)] = [
    ([], "at least one tag name is needed"),
    (["alpha", "  "], "a tag name must not be empty or only spaces"),
    (
      ["a,b"],
      "the tag name `a,b` contains a comma, which the plugin would split into several tags",
    ),
  ]
  for entry in cases {
    try validate(entry.0) catch {
      InvalidArgument(message~) => assert_eq(message, entry.1)
      error => fail(message_of(error))
    } noraise {
      _ => fail("expected \{entry.1}")
    }
  }
}

///|
test "adding appends only the names the record does not carry in any case" {
  assert_eq(
    Change::Add.merge(["alpha", "Beta"], ["ALPHA", "gamma", "Gamma"]),
    Some(["alpha", "Beta", "gamma"]),
  )
  assert_eq(Change::Add.merge(["alpha", "Beta"], ["beta"]), None)
  assert_eq(Change::Add.merge([], ["alpha"]), Some(["alpha"]))
}

///|
test "removing drops every name that matches a requested one in any case" {
  assert_eq(
    Change::Remove.merge(["alpha", "Beta", "gamma"], ["beta", "ALPHA"]),
    Some(["gamma"]),
  )
  assert_eq(Change::Remove.merge(["alpha"], ["delta"]), None)
  assert_eq(Change::Remove.merge(["alpha"], ["Alpha"]), Some([]))
}

///|
test "a read-back reports the added names missing and the removed names still present" {
  assert_eq(Change::Add.unsaved(["Alpha"], ["alpha", "gamma"]), ["gamma"])
  assert_eq(Change::Add.unsaved(["alpha", "gamma"], ["ALPHA", "Gamma"]), [])
  assert_eq(Change::Remove.unsaved(["Alpha", "beta"], ["alpha", "gamma"]), [
    "alpha",
  ])
  assert_eq(Change::Remove.unsaved(["beta"], ["alpha"]), [])
}

///|
async test "a change that leaves the tags as they are is not written" {
  let record = FakeRecord::new(["alpha"])
  let after = record.change(Remove, ["delta"])
  assert_eq(after, ["alpha"])
  assert_eq(record.writes, [])
  assert_eq(record.reads, 1)
}

///|
async test "a change writes the merged names and answers the names read back" {
  let record = FakeRecord::new(["alpha"])
  let after = record.change(Add, [" gamma "])
  assert_eq(record.writes, [["alpha", "gamma"]])
  assert_eq(record.reads, 2)
  assert_eq(after, ["alpha", "gamma"])
}

///|
async test "a write the plugin dropped is reported with the names it lost" {
  let record = FakeRecord::new(["alpha"], saves=false)
  try record.change(Add, ["gamma", "delta"]) catch {
    Decode(message~) =>
      assert_eq(
        message, "Redmine accepted the update without saving the tags `gamma`, `delta`; the fake dropped it",
      )
    error => fail(message_of(error))
  } noraise {
    _ => fail("a dropped write must not be reported as a success")
  }
}

///|
async test "invalid names are refused before the tags are read" {
  let record = FakeRecord::new(["alpha"])
  try record.change(Add, ["a,b"]) catch {
    InvalidArgument(..) => ()
    error => fail(message_of(error))
  } noraise {
    _ => fail("expected the comma to be refused")
  }
  assert_eq(record.reads, 0)
}

///|
test "a record's tags are read as their names" {
  let record = @json.parse(
    (
      #|{"id":42,"tags":[{"id":1,"name":"alpha"},{"id":9,"name":"Beta Tag"}]}
    ),
  )
  let names = names_in(record, absent="unused") catch {
    error => fail(message_of(error))
  }
  assert_eq(names, ["alpha", "Beta Tag"])
}

///|
test "a record without tags is reported with the reason the caller gives" {
  try names_in(Json::object({ "id": 42 }), absent="tags are off") catch {
    Decode(message~) =>
      assert_eq(
        message, "The server answered, but the response could not be read: it has no `tags`; tags are off",
      )
    error => fail(message_of(error))
  } noraise {
    _ => fail("expected the missing tags to be reported")
  }
}

///|
test "a catalogue answer decodes into names and counts" {
  let json = @json.parse(
    (
      #|{"tags":[{"id":9,"name":"alpha","count":2}],"total_count":1,"tag_type":"Issue"}
    ),
  )
  let tags : Array[Tag] = @decode.decode_field(json, "tags") catch {
    error => fail(message_of(error))
  }
  assert_eq(tags, [{ name: "alpha", count: 2, }])
}

///|
test "an empty 403 from the catalogue names the missing administrator rights" {
  assert_eq(
    Json(admin_needed(@redmine.Response(status=403, errors=[]))),
    Json(@redmine.Response(status=403, errors=[ADMIN_NEEDED])),
  )
}

///|
test "any other failure of the catalogue is kept as it came" {
  for
    error in [
      @redmine.Response(status=403, errors=["You are not authorized"]),
      @redmine.Response(status=422, errors=["Tag type is not provided"]),
      @redmine.Transport(message="connection refused"),
    ] {
    assert_eq(Json(admin_needed(error)), Json(error))
  }
}
