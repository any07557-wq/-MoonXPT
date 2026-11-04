///|
test "binary bounds integers alignment" {
  assert_eq(u16be(b"\x12\x34", 0), 4660)
  assert_eq(u32be(b"\xff\xff\xff\xff", 0), 4294967295L)
  for n in [0, 1, 79, 80, 81, 2147483647] {
    assert_eq((n % 80 + padding(n)) % 80, 0)
  }
  try field(b"x", 2147483647, 2) catch {
    XptError(d) => assert_eq(d.kind, "bounds")
  } noraise {
    _ => assert_true(false)
  }
  try decimal_field(b"999999999999999", 0, 15) catch {
    XptError(d) => assert_eq(d.kind, "limit")
  } noraise {
    _ => assert_true(false)
  }
  let b = ByteBuilder::new(8)
  b.u16(0, 65535)
  b.u32(2, 4294967295L)
  assert_eq(b.bytes(), b"\xff\xff\xff\xff\xff\xff  ")
  assert_eq(header("LIBRARY").length(), 80)
  assert_true(header_is(header("NAMESTR"), "NAMESTR"))
}
