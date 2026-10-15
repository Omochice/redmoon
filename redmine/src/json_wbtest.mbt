///|
test "strip_nulls removes null members at every depth" {
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
test "strip_nulls keeps null array elements" {
  inspect(
    strip_nulls(@json.parse("{\"a\":[null,1,null]}")).stringify(),
    content=(
      #|{"a":[null,1,null]}
    ),
  )
}

///|
test "strip_nulls leaves scalars alone" {
  inspect(strip_nulls(Json::null()).stringify(), content="null")
  inspect(strip_nulls(Json::number(1)).stringify(), content="1")
}
