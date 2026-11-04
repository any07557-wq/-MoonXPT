///|
test "independent SAS numeric vectors and all 28 missing values" {
  let vectors : Array[(Bytes, Double)] = [
    (b"\x00\x00\x00\x00\x00\x00\x00\x00", 0.0),
    (b"\x41\x10\x00\x00\x00\x00\x00\x00", 1.0),
    (b"\xc1\x10\x00\x00\x00\x00\x00\x00", -1.0),
    (b"\x40\x80\x00\x00\x00\x00\x00\x00", 0.5),
    (b"\x42\x64\x00\x00\x00\x00\x00\x00", 100.0),
    (b"\x00\x10\x00\x00\x00\x00\x00\x00", @math.pow(2.0, -260.0)),
    (b"\x7f\x10\x00\x00\x00\x00\x00\x00", @math.pow(2.0, 248.0)),
  ]
  for (raw, n) in vectors {
    assert_eq(decode_numeric(raw), Finite(n))
    assert_eq(encode_numeric(Finite(n), 8), raw)
  }
  let mut count = 0
  for tag = 0; tag < 256; tag = tag + 1 {
    if valid_missing(tag.to_byte()) {
      for width = 2; width <= 8; width = width + 1 {
        let expected = Bytes::from_array([tag.to_byte()]) +
          Bytes::make(width - 1, b'\x00')
        assert_eq(encode_numeric(Missing(tag.to_byte()), width), expected)
        assert_eq(decode_numeric(expected), Missing(tag.to_byte()))
      }
      count = count + 1
    }
  }
  assert_eq(count, 28)
  assert_eq(decode_numeric(b"\x41\x10"), Finite(1.0))
}

///|
test "IBM precision and representable range are explicit" {
  assert_eq(decode_numeric(b"\x40\xff\xff\xff\xff\xff\xff\xff"), Finite(1.0))
  for x in [@math.pow(2.0, -261.0), @math.pow(2.0, 252.0), 0.0 / 0.0, 1.0 / 0.0] {
    try encode_numeric(Finite(x), 8) catch {
      XptError(d) => assert_eq(d.kind, "numeric")
    } noraise {
      _ => assert_true(false)
    }
  }
  assert_eq(encode_numeric(Finite(1.1), 2), b"\x41\x11")
  assert_eq(decode_numeric(b"\x41\x11"), Finite(1.0625))
  // Last valid exponent bin extends to just below 2^252.
  assert_eq(
    decode_numeric(encode_numeric(Finite(@math.pow(2.0, 251.0)), 8)),
    Finite(@math.pow(2.0, 251.0)),
  )
}

///|
test "ASCII and Windows-1252 strict bidirectional views" {
  for n = 0; n < 256; n = n + 1 {
    if !(n == 129 || n == 141 || n == 143 || n == 144 || n == 157) {
      let raw = Bytes::from_array([n.to_byte()])
      assert_eq(encode_text(decode_text(raw, Windows1252), Windows1252), raw)
    }
  }
  assert_eq(decode_text(b"\x80\xe9  ", Windows1252), "€é  ")
  assert_eq(encode_text("€é  ", Windows1252), b"\x80\xe9  ")
  try decode_text(b"\x80", Ascii) catch {
    XptError(d) => assert_eq(d.kind, "encoding")
  } noraise {
    _ => assert_true(false)
  }
  try decode_text(b"\x81", Windows1252) catch {
    XptError(d) => assert_eq(d.kind, "encoding")
  } noraise {
    _ => assert_true(false)
  }
  try encode_text("中", Windows1252) catch {
    XptError(d) => assert_eq(d.kind, "encoding")
  } noraise {
    _ => assert_true(false)
  }
}
