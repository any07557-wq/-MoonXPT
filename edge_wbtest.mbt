///|
fn character_schema(name : String, width : Int32) -> DatasetMetadata raise {
  DatasetMetadata::new(name, [VariableMetadata::new("TEXT", Text, width, 0)])
}

///|
test "blank trailing character rows need a hint; full 80-byte blank rows are data" {
  let meta = character_schema("BLANKS", 4)
  let data = encode_library(LibraryMetadata::new(), WriteOptions::default()) +
    encode_dataset(meta, WriteOptions::default()) +
    b"A       " +
    Bytes::make(72, b' ')
  let strict = Reader::new(input_from_bytes(data))
  ignore(strict.next_dataset())
  try strict.next_row() catch {
    XptError(d) => assert_eq(d.kind, "ambiguous")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  let hinted = Reader::new(input_from_bytes(data), options={
    ..ReadOptions::default(),
    row_hints: { "BLANKS": 2L },
  })
  ignore(hinted.next_dataset())
  assert_eq(hinted.next_row().unwrap().raw, b"A   ")
  assert_eq(hinted.next_row().unwrap().raw, b"    ")
  assert_eq(hinted.next_row(), None)
  let full = character_schema("FULL", 80)
  let bytes = encode_library(LibraryMetadata::new(), WriteOptions::default()) +
    encode_dataset(full, WriteOptions::default()) +
    Bytes::make(80, b' ')
  let r = Reader::new(input_from_bytes(bytes))
  ignore(r.next_dataset())
  assert_eq(r.next_row().unwrap().raw, Bytes::make(80, b' '))
  assert_eq(r.next_row(), None)
}

///|
test "invalid pseudo-member headers are data; fully valid polyglots are diagnosed" {
  let opts = WriteOptions::default()
  let meta = character_schema("HEADER", 80)
  let bytes = encode_library(LibraryMetadata::new(), opts) +
    encode_dataset(meta, opts) +
    header("MEMBER")
  let reader = Reader::new(input_from_bytes(bytes, chunk_size=1))
  ignore(reader.next_dataset())
  assert_eq(reader.next_row().unwrap().raw, header("MEMBER"))
  assert_eq(reader.next_row(), None)
  // This candidate gets past MEMBER and DSCRPTR before its real header fails.
  // The two probed physical records must be replayed as current observations.
  let first = encode_dataset(character_schema("FAKE", 8), opts)[:80].to_owned()
  let body = first + header("DSCRPTR") + Bytes::make(80, b'x')
  let replay = Reader::new(
    input_from_bytes(
      encode_library(LibraryMetadata::new(), opts) +
      encode_dataset(meta, opts) +
      body,
      chunk_size=1,
    ),
  )
  ignore(replay.next_dataset())
  assert_eq(replay.next_row().unwrap().raw, first)
  assert_eq(replay.next_row().unwrap().raw, header("DSCRPTR"))
  assert_eq(replay.next_row().unwrap().raw, Bytes::make(80, b'x'))
  assert_eq(replay.next_row(), None)
  assert_eq(replay.next_dataset(), None)
  let vars : Array[VariableMetadata] = []
  for i = 0; i < 4; i = i + 1 {
    vars.push(
      VariableMetadata::new(
        "C" + i.to_string(),
        Text,
        160,
        160 * i,
        number=i + 1,
      ),
    )
  }
  let poly = DatasetMetadata::new("POLYGLOT", vars)
  let fake = encode_dataset(character_schema("FAKE", 8), opts)
  assert_eq(fake.length(), 640)
  let bytes = encode_library(LibraryMetadata::new(), opts) +
    encode_dataset(poly, opts) +
    fake
  let strict = Reader::new(input_from_bytes(bytes))
  ignore(strict.next_dataset())
  try strict.next_row() catch {
    XptError(d) => assert_eq(d.kind, "ambiguous")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  let hinted = Reader::new(input_from_bytes(bytes), options={
    ..ReadOptions::default(),
    row_hints: { "POLYGLOT": 1L },
  })
  ignore(hinted.next_dataset())
  assert_eq(hinted.next_row().unwrap().raw, fake)
  assert_eq(hinted.next_row(), None)
  assert_eq(hinted.next_dataset(), None)
}

///|
test "exact byte limit accepts final EOF and rejects an extra byte" {
  let src = Input::new(
    {
      let mut p = 0
      n => {
        let end = (p + n).min(3)
        let out = b"abc"[p:end].to_owned()
        p = end
        out
      }
    },
    max_bytes=3L,
  )
  assert_eq(src.required(3), b"abc")
  assert_eq(src.exact(1, eof_ok=true), None)
  let src = input_from_bytes(b"abcd")
  src.limit = 3L
  ignore(src.required(3))
  try src.exact(1, eof_ok=true) catch {
    XptError(d) => assert_eq(d.kind, "limit")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
