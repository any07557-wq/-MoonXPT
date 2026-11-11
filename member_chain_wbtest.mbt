///|
fn mmeta(name : String, width : Int32) -> DatasetMetadata raise XptError {
  let meta = bmeta(width)
  { ..meta, name: encode_text(name, Ascii), }
}

///|
fn mfile(members : Array[(DatasetMetadata, Bytes)]) -> Bytes raise XptError {
  let opts = WriteOptions::default()
  let mut bytes = encode_library(LibraryMetadata::new(), opts)
  for (meta, raw) in members {
    bytes = bytes +
      encode_dataset(meta, opts) +
      raw +
      Bytes::make(padding(raw.length()), b' ')
  }
  bytes
}

///|
fn mread(
  bytes : Bytes,
  hints~ : Map[String, Int64] = {},
  chunk~ : Int32 = 4096,
  options~ : BoundaryOptions = BoundaryOptions::default(),
  nonseek~ : Bool = false,
) -> Array[(String, Int64)] raise {
  let mut at = 0
  let input = if nonseek {
    Input::new(n => {
      let end = (at + n.min(chunk)).min(bytes.length())
      let b = bytes[at:end].to_owned()
      at = end
      b
    })
  } else {
    input_from_bytes(bytes, chunk_size=chunk)
  }
  let reader = Reader::new(
    input,
    options={ ..ReadOptions::default(), row_hints: hints, },
    boundary_options=options,
  )
  let result : Array[(String, Int64)] = []
  while reader.next_dataset() is Some(meta) {
    let mut rows = 0L
    while reader.next_raw() is Some(_) {
      rows = rows + 1L
    }
    assert_eq(reader.boundary_report().unwrap().boundary_status, "validated")
    result.push((text_field(meta.name, Ascii), rows))
  }
  result
}

///|
fn unique_multi() -> Bytes raise XptError {
  mfile([
    (mmeta("FIRST", 81), Bytes::make(81, b'a')),
    (mmeta("SECOND", 80), Bytes::make(80, b'b')),
  ])
}

///|
test "M01 unique complete two-member path without hints" {
  assert_eq(mread(unique_multi()), [("FIRST", 1L), ("SECOND", 1L)])
}

///|
test "M02 three schemas with member-bound hints" {
  let bytes = mfile([
    (mmeta("A", 81), Bytes::make(81, b'a')),
    (mmeta("B", 83), Bytes::make(83, b'b')),
    (mmeta("C", 89), Bytes::make(89, b'c')),
  ])
  assert_eq(mread(bytes, hints={ "B": 1L, "C": 1L }), [
    ("A", 1L),
    ("B", 1L),
    ("C", 1L),
  ])
}

///|
test "M03 first member zero observations" {
  assert_eq(
    mread(
      mfile([(mmeta("A", 0), b""), (mmeta("B", 80), Bytes::make(80, b'b'))]),
    ),
    [("A", 0L), ("B", 1L)],
  )
}

///|
test "M04 middle member zero observations" {
  let bytes = mfile([
    (mmeta("A", 80), Bytes::make(80, b'a')),
    (mmeta("B", 0), b""),
    (mmeta("C", 80), Bytes::make(80, b'c')),
  ])
  assert_eq(mread(bytes, hints={ "A": 1L, "C": 1L }), [
    ("A", 1L),
    ("B", 0L),
    ("C", 1L),
  ])
}

///|
test "M05 last member zero observations" {
  let bytes = mfile([
    (mmeta("A", 80), Bytes::make(80, b'a')),
    (mmeta("B", 8), b""),
  ])
  assert_eq(mread(bytes, hints={ "A": 1L }), [("A", 1L), ("B", 0L)])
}

///|
test "M06 member row widths change" {
  let bytes = mfile([
    (mmeta("A", 79), Bytes::make(79, b'a')),
    (mmeta("B", 81), Bytes::make(81, b'b')),
  ])
  assert_eq(mread(bytes, hints={ "B": 1L }), [("A", 1L), ("B", 1L)])
}

///|
test "M07 blank last row remains a row-count ambiguity on a valid chain" {
  let bytes = mfile([
    (mmeta("A", 4), b"a       "),
    (mmeta("B", 80), Bytes::make(80, b'b')),
  ])
  boundary_raises(
    () => ignore(mread(bytes, hints={ "B": 1L })),
    "E_V5_ROW_COUNT_AMBIGUOUS",
  )
  assert_eq(mread(bytes, hints={ "A": 2L, "B": 1L }), [("A", 2L), ("B", 1L)])
}

///|
test "M08 marker embedded inside a field is ordinary data" {
  let raw = b"x" + header("MEMBER") + Bytes::make(79, b'z')
  assert_eq(mread(mfile([(mmeta("A", 160), raw)])), [("A", 1L)])
}

///|
test "M09 aligned marker without complete structure remains data" {
  assert_eq(mread(mfile([(mmeta("A", 80), header("MEMBER"))])), [("A", 1L)])
}

///|
test "M10 fake member with invalid DSCRPTR remains observation bytes" {
  let head = encode_dataset(mmeta("FAKE", 8), WriteOptions::default())
  let raw = head[:80].to_owned() + Bytes::make(80, b'x') + head[160:].to_owned()
  assert_eq(mread(mfile([(mmeta("A", 80), raw)])), [("A", 8L)])
}

///|
test "M11 mismatched NAMESTR count is not a trusted boundary" {
  let head = encode_dataset(mmeta("FAKE", 8), WriteOptions::default())
  let edit = ByteBuilder::new(head.length())
  edit.put(0, head)
  edit.put(374, b"0002")
  assert_eq(mread(mfile([(mmeta("A", 80), edit.bytes())])), [("A", 8L)])
}

///|
test "M12 136-byte descriptors" {
  let data = fixture_library() +
    fixture_headers(136) +
    encode_numeric(Finite(1.0), 8) +
    Bytes::make(72, b' ')
  assert_eq(mread(data, hints={ "TEST": 1L }), [("TEST", 1L)])
}

///|
test "M13 140-byte descriptors" {
  let data = fixture_library() +
    fixture_headers(140) +
    encode_numeric(Finite(1.0), 8) +
    Bytes::make(72, b' ')
  assert_eq(mread(data, hints={ "TEST": 1L }), [("TEST", 1L)])
}

///|
test "M14 reordered descriptors with a physical storage gap" {
  let meta = DatasetMetadata::new("ORDER", [
    VariableMetadata::new("LATE", Text, 1, 80),
    VariableMetadata::new("EARLY", Text, 2, 0),
  ])
  let raw = Bytes::make(81, b'x')
  assert_eq(mread(mfile([(meta, raw)])), [("ORDER", 1L)])
}

///|
test "M15 candidate headers across small chunks and nonseekable replay" {
  for chunk in [1, 7, 79, 80, 81, 4096] {
    assert_eq(mread(unique_multi(), chunk~), [("FIRST", 1L), ("SECOND", 1L)])
    assert_eq(mread(unique_multi(), chunk~, nonseek=true), [
      ("FIRST", 1L),
      ("SECOND", 1L),
    ])
  }
}

///|
test "M16 truncated next header is not EOF" {
  let bytes = unique_multi()
  try
    mread(bytes[:bytes.length() - 13].to_owned(), hints={
      "FIRST": 1L,
      "SECOND": 1L,
    })
  catch {
    XptError(d) => assert_eq(d.kind, "truncated")
    e => raise e
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "M17 unexplained trailing bytes are rejected" {
  try
    mread(
      mfile([(mmeta("A", 81), Bytes::make(81, b'a'))]) + Bytes::make(80, b'x'),
    )
  catch {
    XptError(_) => ()
    e => raise e
  } noraise {
    _ => assert_true(false)
  }
  let broken = mfile([
    (mmeta("A", 81), Bytes::make(81, b'a')),
    (mmeta("B", 81), Bytes::make(80, b'b')),
  ])
  boundary_raises(() => ignore(mread(broken)), "E_V5_TRAILING_GARBAGE")
}

///|
test "M18 two complete legal paths are distinct from row-count ambiguity" {
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
  let bytes = mfile([
    (
      DatasetMetadata::new("POLYGLOT", vars),
      encode_dataset(mmeta("FAKE", 8), WriteOptions::default()),
    ),
  ])
  boundary_raises(() => ignore(mread(bytes)), "E_V5_MEMBER_BOUNDARY_AMBIGUOUS")
  assert_eq(mread(bytes, hints={ "POLYGLOT": 1L }), [("POLYGLOT", 1L)])
}

///|
test "M19 candidate and replay limits are enforced" {
  let bytes = mfile([
    (mmeta("A", 81), Bytes::make(81, b'a')),
    (mmeta("B", 80), Bytes::make(80, b'b')),
    (mmeta("C", 80), Bytes::make(80, b'c')),
  ])
  boundary_raises(
    () => {
      ignore(
        mread(bytes, options={
          ..BoundaryOptions::default(),
          max_boundary_candidates: 1,
        }),
      )
    },
    "E_V5_RESOURCE_LIMIT",
  )
  boundary_raises(
    () => {
      ignore(
        mread(unique_multi(), nonseek=true, options={
          ..BoundaryOptions::default(),
          max_replay_bytes: 640,
        }),
      )
    },
    "E_V5_RESOURCE_LIMIT",
  )
  assert_eq(
    mread(unique_multi(), options={
      ..BoundaryOptions::default(),
      max_replay_bytes: 640,
    }),
    [("FIRST", 1L), ("SECOND", 1L)],
  )
  boundary_raises(
    () => {
      ignore(
        mread(unique_multi(), options={
          ..BoundaryOptions::default(),
          max_search_steps: 1,
        }),
      )
    },
    "E_V5_RESOURCE_LIMIT",
  )
}

///|
test "M20 member-count limit cannot silently truncate a chain" {
  let r = Reader::new(input_from_bytes(unique_multi()), options={
    ..ReadOptions::default(),
    limits: { ..Limits::default(), max_datasets: 1, },
  })
  ignore(r.next_dataset())
  boundary_raises(
    () => {
      while r.next_raw() is Some(_) {
        ()
      }
    },
    "E_V5_RESOURCE_LIMIT",
  )
}

///|
test "M21 OBS-like bytes inside data are ordinary observations" {
  assert_eq(mread(mfile([(mmeta("A", 80), header("OBS"))])), [("A", 1L)])
}

///|
test "M22 final EOF standard padding is validated" {
  assert_eq(mread(mfile([(mmeta("A", 81), Bytes::make(81, b'a'))])), [("A", 1L)])
}

///|
test "M23 unaligned fully valid header is not a member candidate" {
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
  vars.push(VariableMetadata::new("LAST", Text, 1, 640, number=5))
  let raw = b"X" + encode_dataset(mmeta("FAKE", 8), WriteOptions::default())
  assert_eq(mread(mfile([(DatasetMetadata::new("UNALIGN", vars), raw)])), [
    ("UNALIGN", 1L),
  ])
}
