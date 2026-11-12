///|
test "stream-relative reposition after a file prefix preserves multi-member offsets" {
  let (created, path) = create_temp("/tmp/moonxpt-prefixed")
  defer ignore(remove_raw(path_bytes(path)))
  let opts = @xpt.WriteOptions::default()
  let a = @xpt.DatasetMetadata::new("FIRST", [
    @xpt.VariableMetadata::new("TEXT", @xpt.Text, 81, 0),
  ])
  let b = @xpt.DatasetMetadata::new("SECOND", [
    @xpt.VariableMetadata::new("TEXT", @xpt.Text, 80, 0),
  ])
  let bytes = @xpt.encode_library(@xpt.LibraryMetadata::new(), opts) +
    @xpt.encode_dataset(a, opts) +
    Bytes::make(81, b'a') +
    Bytes::make(79, b' ') +
    @xpt.encode_dataset(b, opts) +
    Bytes::make(80, b'b')
  created.write(b"envelope" + bytes)
  created.close()
  let file = File::open(path)
  defer file.cleanup()
  assert_eq(file.read(8), b"envelope")
  let reader = @xpt.Reader::new(file.input())
  assert_eq(
    @xpt.text_field(reader.next_dataset().unwrap().name, @xpt.Ascii),
    "FIRST",
  )
  let first = reader.next_row().unwrap()
  assert_eq(first.offset, 880L)
  assert_eq(first.raw, Bytes::make(81, b'a'))
  assert_eq(reader.next_row(), None)
  assert_eq(
    @xpt.text_field(reader.next_dataset().unwrap().name, @xpt.Ascii),
    "SECOND",
  )
  let second = reader.next_row().unwrap()
  assert_eq(second.offset, 1680L)
  assert_eq(second.raw, Bytes::make(80, b'b'))
  assert_eq(reader.next_row(), None)
  assert_eq(reader.next_dataset(), None)
}
