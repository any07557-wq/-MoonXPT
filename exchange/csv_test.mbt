///|
test "CSV exporter quotes only required fields and retains spaces" {
  let bytes = @exchange.csv_record([
    "plain", "a,b", "a\"b", "c\rd\ne", "", "  .A  ",
  ])
  assert_eq(bytes, b"plain,\"a,b\",\"a\"\"b\",\"c\rd\ne\",,  .A  \n")
}
