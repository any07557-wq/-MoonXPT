///|
fn csv_source(bytes : Bytes, chunk : Int32) -> @exchange.CsvReader raise {
  let mut at = 0
  @exchange.CsvReader::new(n => {
    let end = (at + n.min(chunk)).min(bytes.length())
    let out = bytes[at:end].to_owned()
    at = end
    out
  })
}

///|
test "quoted CRLF comma quote empty and spaces across every chunk" {
  for chunk in [1, 2, 7, 4096] {
    let r = csv_source(b"a,b\r\n\"x,y\",\"a\"\"b\r\nc\"\n,  .A  \n", chunk)
    assert_eq(r.next_record(), Some(["a", "b"]))
    assert_eq(r.next_record(), Some(["x,y", "a\"b\r\nc"]))
    assert_eq(r.next_record(), Some(["", "  .A  "]))
    assert_eq(r.next_record(), None)
  }
}

///|
test "malformed CSV is rejected rather than repaired" {
  for
    raw in [
      b"\"open", b"a\"b\n", b"\"x\" y\n", b"x\ry", b"\xff\n", b"\xef\xbb\xbfx\n",
    ] {
    let r = csv_source(raw, 1)
    try r.next_record() catch {
      _ => ()
    } noraise {
      _ => assert_true(false)
    }
  }
}
