///|
test "an executable the keychain no longer trusts is told how to recover" {
  inspect(
    refusal(-25308, Some("https://r.example.com")),
    content="the keychain did not let this redmoon executable read the API key for https://r.example.com, which happens after redmoon is rebuilt or upgraded; run `redmoon logout --endpoint https://r.example.com` and then `redmoon login --endpoint https://r.example.com`",
  )
}

///|
test "the recovery hint without a known account stays generic" {
  inspect(
    refusal(-25308, None),
    content="the keychain did not let this redmoon executable read the stored API keys, which happens after redmoon is rebuilt or upgraded; run `redmoon logout --endpoint <endpoint>` and then `redmoon login --endpoint <endpoint>`",
  )
}

///|
test "other refusal codes keep the plain message" {
  inspect(
    refusal(-25293, Some("https://r.example.com")),
    content="the credential store refused the operation (code -25293)",
  )
}
