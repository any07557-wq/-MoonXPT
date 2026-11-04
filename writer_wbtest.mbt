///|
test "multiple schemas, empty member and all missing tags through writer" {
  let bytes : Array[Byte] = []
  let writer = Writer::new(Output::new(b => bytes.push_iter(b.iter())))
  let first = DatasetMetadata::new("TAGS", [
    VariableMetadata::new("NUM", Number, 8, 0),
  ])
  writer.begin_dataset(first)
  for tag = 0; tag < 256; tag = tag + 1 {
    if valid_missing(tag.to_byte()) {
      writer.write_row([Numeric(Missing(tag.to_byte()))])
    }
  }
  writer.begin_dataset(
    DatasetMetadata::new("EMPTY", [VariableMetadata::new("TXT", Text, 10, 0)]),
  )
  writer.begin_dataset(
    DatasetMetadata::new("WORDS", [VariableMetadata::new("TXT", Text, 10, 0)]),
  )
  writer.write_row([Character(b".A")])
  writer.finish()
  let r = Reader::new(
    input_from_bytes(Bytes::from_array(bytes), chunk_size=7),
    options={
      ..ReadOptions::default(),
      row_hints: { "TAGS": 28L, "EMPTY": 0L, "WORDS": 1L },
    },
  )
  ignore(r.next_dataset())
  for tag = 0; tag < 256; tag = tag + 1 {
    if valid_missing(tag.to_byte()) {
      assert_eq(
        r.next_row().unwrap().raw,
        Bytes::from_array([tag.to_byte()]) + Bytes::make(7, b'\x00'),
      )
    }
  }
  assert_eq(r.next_row(), None)
  assert_eq(text_field(r.next_dataset().unwrap().name, Ascii), "EMPTY")
  assert_eq(r.next_row(), None)
  assert_eq(text_field(r.next_dataset().unwrap().name, Ascii), "WORDS")
  assert_eq(r.next_row().unwrap().values, [Character(b".A        ")])
  assert_eq(r.next_row(), None)
  assert_eq(r.next_dataset(), None)
}

///|
test "writer rejects failure and cannot finish poisoned output" {
  let writer = Writer::new(Output::new(_ => ()))
  writer.begin_dataset(
    DatasetMetadata::new("TEST", [VariableMetadata::new("TXT", Text, 2, 0)]),
  )
  try writer.write_row([Character(b"abc")]) catch {
    XptError(d) => assert_eq(d.kind, "width")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  try writer.finish() catch {
    XptError(d) => assert_eq(d.kind, "state")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
