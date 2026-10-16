///|
test "the create body omits delay when none is given" {
  assert_eq(
    relation_body(3, Blocks, None).stringify(),
    "{\"relation\":{\"issue_to_id\":3,\"relation_type\":\"blocks\"}}",
  )
}

///|
test "the create body carries delay when given" {
  assert_eq(
    relation_body(3, Precedes, Some(2)).stringify(),
    "{\"relation\":{\"issue_to_id\":3,\"relation_type\":\"precedes\",\"delay\":2}}",
  )
}

///|
test "a relation type round-trips through its wire name" {
  let all = [
    Relates,
    Duplicates,
    Duplicated,
    Blocks,
    Blocked,
    Precedes,
    Follows,
    CopiedTo,
    CopiedFrom,
  ]
  for relation_type in all {
    assert_eq(Type::from_wire(relation_type.to_wire()), Some(relation_type))
  }
  assert_eq(Type::from_wire("parent"), None)
}

///|
test "a relation decodes from Redmine's response with a null delay" {
  let text =
    #|{"relation":{"id":1,"issue_id":2,"issue_to_id":3,"relation_type":"copied_to","delay":null}}
  let json = @json.parse(text) catch { _ => fail("fixture is not JSON") }
  let relation : Relation = @decode.decode_field(
    @wire.strip_nulls(json),
    "relation",
  ) catch {
    _ => fail("relation did not decode")
  }
  assert_eq(relation.id, 1)
  assert_eq(relation.issue_to_id, 3)
  assert_eq(relation.relation_type, CopiedTo)
  assert_eq(relation.delay, None)
}

///|
test "an unknown relation type fails to decode" {
  let json = @json.parse("\"parent\"") catch {
    _ => fail("fixture is not JSON")
  }
  try {
    let _ : Type = @json.from_json(json)
  } catch {
    _ => ()
  } noraise {
    _ => fail("expected a decode error")
  }
}
