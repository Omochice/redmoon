///|
test "null members are removed at every depth" {
  let json = @json.parse(
    "{\"a\":null,\"b\":1,\"c\":{\"d\":null,\"e\":{\"f\":null,\"g\":\"x\"}},\"h\":[{\"i\":null,\"j\":2}]}",
  )
  inspect(
    strip_nulls(json).stringify(),
    content=(
      #|{"b":1,"c":{"e":{"g":"x"}},"h":[{"j":2}]}
    ),
  )
}

///|
test "null array elements are kept" {
  inspect(
    strip_nulls(@json.parse("{\"a\":[null,1,null]}")).stringify(),
    content=(
      #|{"a":[null,1,null]}
    ),
  )
}

///|
test "scalars are left alone when nulls are stripped" {
  inspect(strip_nulls(Json::null()).stringify(), content="null")
  inspect(strip_nulls(Json::number(1)).stringify(), content="1")
}
