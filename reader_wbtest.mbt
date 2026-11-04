///|
fn fixture_library() -> Bytes raise {
  let real = ByteBuilder::new(80)
  real.put(0, b"SAS     SAS     SASLIB  ")
  header("LIBRARY") + real.bytes() + Bytes::make(80, b' ')
}

///|
test "pull stream hints preserve short blank rows and member transitions" {
  let file = fixture_library() +
    fixture_headers(140) +
    encode_numeric(Finite(1.0), 8) +
    Bytes::make(72, b' ') +
    fixture_headers(136) +
    encode_numeric(Missing(b'A'), 8) +
    Bytes::make(72, b' ')
  // Replace the second dataset name, without relying on the writer.
  let edit = ByteBuilder::new(file.length())
  edit.put(0, file)
  edit.put(240 + 640 + 80 + 160 + 8, b"SECOND  ")
  let bytes = edit.bytes()
  for chunk in [1, 7, 79, 80, 81, 4096] {
    let reader = Reader::new(input_from_bytes(bytes, chunk_size=chunk), options={
      ..ReadOptions::default(),
      row_hints: { "TEST": 1L, "SECOND": 1L },
    })
    assert_eq(text_field(reader.next_dataset().unwrap().name, Ascii), "TEST")
    assert_eq(reader.next_row().unwrap().values, [Numeric(Finite(1.0))])
    assert_eq(reader.next_row(), None)
    assert_eq(text_field(reader.next_dataset().unwrap().name, Ascii), "SECOND")
    assert_eq(reader.next_row().unwrap().values, [Numeric(Missing(b'A'))])
    assert_eq(reader.next_row(), None)
    assert_eq(reader.next_dataset(), None)
  }
}

///|
test "strict tail ambiguity and explicit compatibility policy" {
  let file = fixture_library() +
    fixture_headers(140) +
    encode_numeric(Finite(1.0), 8) +
    Bytes::make(72, b' ')
  let strict = Reader::new(input_from_bytes(file))
  ignore(strict.next_dataset())
  try strict.next_row() catch {
    XptError(d) => assert_eq(d.kind, "ambiguous")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  let compat = Reader::new(input_from_bytes(file), options={
    ..ReadOptions::default(),
    tail_policy: TrimPadding,
  })
  ignore(compat.next_dataset())
  assert_eq(compat.next_row().unwrap().values, [Numeric(Finite(1.0))])
  assert_eq(compat.next_row(), None)
}

///|
test "partial physical EOF is truncation and early stop is bounded" {
  let file = fixture_library() + fixture_headers(140) + b"x"
  let reader = Reader::new(input_from_bytes(file))
  ignore(reader.next_dataset())
  try reader.next_row() catch {
    XptError(d) => assert_eq(d.kind, "truncated")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  let mut requested = 0
  let bytes = fixture_library() + fixture_headers(140) + Bytes::make(8000, b' ')
  let mut pos = 0
  let reader = Reader::new(
    Input::new(n => {
      requested = requested + n
      let out = bytes[pos:pos + n].to_owned()
      pos = pos + n
      out
    }),
    options={ ..ReadOptions::default(), row_hints: { "TEST": 1000L }, },
  )
  ignore(reader.next_dataset())
  ignore(reader.next_row())
  assert_true(requested < 1000)
}
