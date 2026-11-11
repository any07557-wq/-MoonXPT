///|
test "A01 A08 not-scanned and explicit policy with poisoned failure" {
  let r = Reader::new(
    input_from_bytes(mfile([(mmeta("A", 80), Bytes::make(80, b'x'))])),
    boundary_options={
      ..BoundaryOptions::default(),
      row_count_policy: RequireExplicitCount,
    },
  )
  assert_eq(r.boundary_report(), None)
  ignore(r.next_dataset())
  assert_eq(r.boundary_report(), None)
  boundary_raises(() => ignore(r.next_raw()), "E_V5_ROW_COUNT_REQUIRED")
  try r.next_raw() catch {
    XptError(d) => assert_eq(d.kind, "state")
    e => raise e
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "A02 A03 inferred and provided reports with snapshot candidates" {
  for hints in [{}, { "A": 1L }] {
    let r = Reader::new(
      input_from_bytes(mfile([(mmeta("A", 81), Bytes::make(81, b'x'))])),
      options={ ..ReadOptions::default(), row_hints: hints, },
    )
    ignore(r.next_dataset())
    while r.next_raw() is Some(_) {
      ()
    }
    let report = r.boundary_report().unwrap()
    assert_eq(report.row_count, Some(1L))
    assert_eq(
      report.row_count_status,
      if hints.is_empty() {
        "inferred"
      } else {
        "provided"
      },
    )
    report.candidate_counts[0] = 999L
    assert_eq(r.boundary_report().unwrap().candidate_counts, [1L])
  }
}

///|
test "A04 A06 row ambiguity retains a validated physical boundary" {
  let r = Reader::new(input_from_bytes(mfile([(mmeta("A", 4), b"a       ")])))
  ignore(r.next_dataset())
  boundary_raises(() => ignore(r.next_raw()), "E_V5_ROW_COUNT_AMBIGUOUS")
  let report = r.boundary_report().unwrap()
  assert_eq(report.row_count_status, "ambiguous")
  assert_eq(report.boundary_status, "validated")
  assert_true(report.candidate_counts.contains(2L))
}

///|
test "A14 writer default rejects the evidenced short character blank-tail risk" {
  let bytes : Array[Byte] = []
  let w = Writer::new(Output::new(b => bytes.push_iter(b.iter())))
  w.begin_dataset(mmeta("A", 4))
  w.write_row([Character(b"    ")])
  boundary_raises(() => w.finish(), "E_V5_WRITER_AMBIGUOUS_TAIL")
  assert_eq(Bytes::from_array(bytes[bytes.length() - 4:]), b"    ")
  try w.finish() catch {
    XptError(d) => assert_eq(d.kind, "state")
    e => raise e
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "A15 writer opt-in reports risk without changing data; wide blanks are allowed" {
  let bytes : Array[Byte] = []
  let w = Writer::new(
    Output::new(b => bytes.push_iter(b.iter())),
    tail_policy=AllowAmbiguousTail,
  )
  w.begin_dataset(mmeta("A", 4))
  w.write_raw(b"    ")
  let report = w.finish_report()
  assert_eq(report.member_count, 1)
  assert_eq(report.row_count, 1L)
  assert_eq(report.members[0].code, Some("E_V5_WRITER_AMBIGUOUS_TAIL"))
  assert_eq(report.members[0].padding_bytes, 76)
  assert_eq(Bytes::from_array(bytes[880:884]), b"    ")
  let wide = Writer::new(Output::new(_ => ()))
  wide.begin_dataset(mmeta("WIDE", 80))
  wide.write_raw(Bytes::make(80, b' '))
  assert_eq(wide.finish_report().members[0].code, None)
}

///|
test "A16 finish reports actual counts including zero-row members" {
  let w = Writer::new(Output::new(_ => ()))
  w.begin_dataset(mmeta("EMPTY", 8))
  w.begin_dataset(mmeta("DATA", 80))
  w.write_raw(Bytes::make(80, b'x'))
  let report = w.finish_report()
  assert_eq(report.member_count, 2)
  assert_eq(report.row_count, 1L)
  assert_eq(report.members.map(x => x.row_count), [0L, 1L])
}

///|
test "A17 old full option and diagnostic records and finish Unit remain source-compatible" {
  let limits = Limits::default()
  let read = ReadOptions::{ limits, tail_policy: Reject, row_hints: {}, }
  let write = WriteOptions::{
    limits,
    timestamp: b"01JAN00:00:00:00",
    max_output_bytes: 10000L,
  }
  let d = Diagnostic::{
    kind: "usage",
    offset: None,
    dataset: None,
    row: None,
    variable: None,
    reason: "legacy",
  }
  assert_eq(d.code(), "E_USAGE")
  let w = Writer::new(Output::new(_ => ()), options=write)
  let done : Unit = w.finish()
  ignore(done)
  let r = Reader::new(
    input_from_bytes(mfile([(mmeta("A", 80), Bytes::make(80, b'x'))])),
    options=read,
  )
  ignore(r.next_dataset())
  ignore(r.next_row())
  assert_eq(r.next_row(), None)
}

///|
test "A18 explicit legacy trim exposes rather than conceals structural ambiguity" {
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
  let r = Reader::new(input_from_bytes(bytes), options={
    ..ReadOptions::default(),
    tail_policy: TrimPadding,
  })
  ignore(r.next_dataset())
  assert_eq(r.next_raw(), None)
  assert_eq(r.boundary_report().unwrap().boundary_status, "ambiguous")
  assert_eq(text_field(r.next_dataset().unwrap().name, Ascii), "FAKE")
  assert_eq(r.next_raw(), None)
  assert_eq(r.next_dataset(), None)
}
