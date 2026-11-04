///|
fn fixture_headers(size : Int32, position~ : Int64 = 0L) -> Bytes raise {
  let first = ByteBuilder::new(80)
  first.put(0, header("MEMBER"))
  first.put(63, b"160")
  first.put(75, encode_text(size.to_string(), Ascii))
  let data = ByteBuilder::new(80)
  data.put(0, b"SAS     TEST    SASDATA ")
  let nh = ByteBuilder::new(80)
  nh.put(0, header("NAMESTR"))
  nh.put(54, b"0001")
  let v = ByteBuilder::new(size, fill=b'\x00')
  v.u16(0, 1)
  v.u16(4, 8)
  v.u16(6, 1)
  v.put(8, b"VALUE   ")
  v.put(16, Bytes::make(40, b' '))
  v.put(56, Bytes::make(8, b' '))
  v.put(72, Bytes::make(8, b' '))
  v.u32(84, position)
  first.bytes() +
  header("DSCRPTR") +
  data.bytes() +
  Bytes::make(80, b' ') +
  nh.bytes() +
  v.bytes() +
  Bytes::make(padding(size), b' ') +
  header("OBS")
}

///|
test "136 and 140 NAMESTR layouts across single-byte reads" {
  for size in [136, 140] {
    let input = input_from_bytes(fixture_headers(size), chunk_size=1)
    let ds = read_dataset(input, input.required(80), Limits::default())
    assert_eq(ds.row_width, 8)
    assert_eq(ds.descriptor_size, size)
    assert_eq(text_field(ds.variables[0].name, Ascii), "VALUE")
    assert_eq(ds.variables[0].number, 1)
  }
  let input = input_from_bytes(fixture_headers(140, position=4294967295L))
  try read_dataset(input, input.required(80), Limits::default()) catch {
    XptError(d) => {
      assert_eq(d.kind, "limit")
      assert_eq(d.offset, Some(400L))
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
