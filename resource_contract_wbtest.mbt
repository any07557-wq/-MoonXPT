///|
test "R12 a row resource cap cannot manufacture a unique format interpretation" {
  let report = resolve_v5_boundary(bmeta(8), 0L, 80L, Bytes::make(79, b' '), limits={
    ..Limits::default(),
    max_rows: 1L,
  })
  assert_eq(report.row_count_status, "ambiguous")
  assert_eq(report.candidate_counts, [10L, 9L, 8L, 7L, 6L, 5L, 4L, 3L, 2L, 1L])
  let reader = Reader::new(
    input_from_bytes(mfile([(mmeta("A", 4), b"a       ")])),
    options={
      ..ReadOptions::default(),
      limits: { ..Limits::default(), max_rows: 1L, },
    },
  )
  ignore(reader.next_dataset())
  boundary_raises(() => ignore(reader.next_raw()), "E_V5_ROW_COUNT_AMBIGUOUS")
}

///|
test "R12 a unique observation exceeding the row cap is a resource error" {
  boundary_raises(
    () => {
      ignore(
        resolve_v5_boundary(bmeta(80), 0L, 80L, Bytes::make(79, b'x'), limits={
          ..Limits::default(),
          max_rows: 0L,
        }),
      )
    },
    "E_V5_RESOURCE_LIMIT",
  )
}
