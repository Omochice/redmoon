///|
test "a listed query decodes, with no project for a global query" {
  let json = @json.parse(
    (
      #|{"queries":[{"id":1,"name":"Issues assigned to me","is_public":true,"project_id":null},{"id":5,"name":"Demo open issues","is_public":false,"project_id":1}],"total_count":2,"offset":0,"limit":25}
    ),
  )
  let queries : Array[Query] = @decode.decode_field(
    @wire.strip_nulls(json),
    "queries",
  ) catch {
    _ => fail("decode")
  }
  assert_eq(queries, [
    { id: 1, name: "Issues assigned to me", is_public: true, project_id: None, },
    { id: 5, name: "Demo open issues", is_public: false, project_id: Some(1), },
  ])
}
