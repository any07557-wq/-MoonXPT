///|
fn bmeta(width : Int32) -> DatasetMetadata raise XptError {
  DatasetMetadata::new(
    "BOUNDARY",
    if width == 0 {
      []
    } else {
      [VariableMetadata::new("TEXT", Text, width, 0)]
    },
  )
}

///|
fn boundary_raises(
  action : () -> Unit raise XptError,
  code : String,
) -> Unit raise {
  try action() catch {
    XptError(d) => assert_eq(d.code(), code)
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "B01 zero rows and zero-column zero rows" {
  assert_eq(resolve_v5_boundary(bmeta(8), 0L, 0L, b"").row_count, Some(0L))
  assert_eq(resolve_v5_boundary(bmeta(0), 0L, 0L, b"").row_count, Some(0L))
}

///|
test "B02 one observation" {
  let r = resolve_v5_boundary(bmeta(80), 0L, 80L, Bytes::make(79, b'x'))
  assert_eq(r.row_count, Some(1L))
  assert_eq(r.row_count_status, "inferred")
}

///|
test "B03 short width with a unique padding candidate" {
  let r = resolve_v5_boundary(bmeta(3), 0L, 80L, Bytes::make(77, b'x') + b"  ")
  assert_eq(r.candidate_counts, [26L])
  assert_eq(r.padding_bytes, Some(2))
}

///|
test "B04 multiple complete interpretations remain ambiguous" {
  let r = resolve_v5_boundary(bmeta(8), 0L, 80L, Bytes::make(79, b' '))
  assert_eq(r.candidate_counts, [10L, 9L, 8L, 7L, 6L, 5L, 4L, 3L, 2L, 1L])
  assert_eq(r.row_count, None)
  assert_eq(r.boundary_status, "validated")
  assert_eq(r.code, Some("E_V5_ROW_COUNT_AMBIGUOUS"))
}

///|
test "B05 width 79" {
  assert_eq(
    resolve_v5_boundary(bmeta(79), 0L, 80L, Bytes::make(78, b'x') + b" ").row_count,
    Some(1L),
  )
}

///|
test "B06 width 80 full blank record is data" {
  assert_eq(
    resolve_v5_boundary(bmeta(80), 0L, 80L, Bytes::make(79, b' ')).row_count,
    Some(1L),
  )
}

///|
test "B07 width 81 validates padding" {
  assert_eq(
    resolve_v5_boundary(bmeta(81), 0L, 160L, Bytes::make(79, b' ')).row_count,
    Some(1L),
  )
}

///|
test "B08 data ends exactly on physical boundary" {
  let r = resolve_v5_boundary(bmeta(8), 0L, 80L, Bytes::make(79, b'x'))
  assert_eq(r.row_count, Some(10L))
  assert_eq(r.padding_bytes, Some(0))
}

///|
test "B09 minimum padding" {
  assert_eq(
    resolve_v5_boundary(bmeta(80), 0L, 80L, b"x").padding_bytes,
    Some(0),
  )
}

///|
test "B10 maximum minimal padding" {
  assert_eq(
    resolve_v5_boundary(bmeta(81), 0L, 160L, Bytes::make(79, b' ')).padding_bytes,
    Some(79),
  )
}

///|
test "B11 nonblank and NUL are not standard padding" {
  for byte in [b'x', b'\x00'] {
    boundary_raises(
      () => {
        ignore(resolve_v5_boundary(bmeta(81), 0L, 160L, Bytes::make(79, byte)))
      },
      "E_V5_INVALID_PADDING",
    )
  }
}

///|
test "B12 observation truncated before completing width" {
  boundary_raises(
    () => {
      ignore(
        resolve_v5_boundary(bmeta(81), 0L, 80L, Bytes::make(79, b'x'), hint=1L),
      )
    },
    "E_V5_ROW_COUNT_HINT_MISMATCH",
  )
}

///|
test "B13 hint proves partial padding physical record" {
  boundary_raises(
    () => ignore(resolve_v5_boundary(bmeta(79), 0L, 79L, b"", hint=1L)),
    "E_V5_TRUNCATED_PADDING",
  )
}

///|
test "B14 hint smaller than nonblank payload" {
  boundary_raises(
    () => {
      ignore(
        resolve_v5_boundary(bmeta(8), 0L, 80L, Bytes::make(79, b'x'), hint=9L),
      )
    },
    "E_V5_ROW_COUNT_HINT_MISMATCH",
  )
}

///|
test "B15 hint larger than physical payload" {
  boundary_raises(
    () => {
      ignore(
        resolve_v5_boundary(bmeta(8), 0L, 80L, Bytes::make(79, b'x'), hint=11L),
      )
    },
    "E_V5_ROW_COUNT_HINT_MISMATCH",
  )
}

///|
test "B16 hint conflicting with trusted member boundary" {
  boundary_raises(
    () => {
      ignore(
        resolve_v5_boundary(bmeta(81), 0L, 80L, Bytes::make(79, b' '), hint=1L),
      )
    },
    "E_V5_ROW_COUNT_HINT_MISMATCH",
  )
}

///|
test "B17 invalid intervals and arithmetic bounds" {
  try
    DatasetMetadata::new("BAD", [
      VariableMetadata::new("X", Number, 8, 2147483647),
    ])
  catch {
    XptError(d) => assert_eq(d.kind, "limit")
  } noraise {
    _ => assert_true(false)
  }
  boundary_raises(
    () => {
      ignore(
        resolve_v5_boundary(bmeta(8), 0L, 80L, b"", hint=9223372036854775807L),
      )
    },
    "E_V5_RESOURCE_LIMIT",
  )
}

///|
test "B18 descriptor order, physical gaps and width" {
  let meta = DatasetMetadata::new("GAPS", [
    VariableMetadata::new("LATE", Text, 1, 80),
    VariableMetadata::new("EARLY", Text, 3, 0),
  ])
  assert_eq(meta.row_width, 81)
  assert_eq(
    resolve_v5_boundary(meta, 0L, 160L, Bytes::make(79, b' ')).row_count,
    Some(1L),
  )
}

///|
test "B19 short all-blank last observation cannot be trimmed by strict auto" {
  let r = resolve_v5_boundary(bmeta(4), 0L, 80L, Bytes::make(79, b' '))
  assert_eq(r.row_count_status, "ambiguous")
  assert_eq(
    resolve_v5_boundary(bmeta(4), 0L, 80L, Bytes::make(79, b' '), hint=2L).row_count,
    Some(2L),
  )
}

///|
test "B20 consecutive blank rows keep the full candidate set" {
  let r = resolve_v5_boundary(
    bmeta(4),
    0L,
    80L,
    Bytes::make(67, b'x') + Bytes::make(12, b' '),
  )
  assert_eq(r.candidate_counts, [20L, 19L, 18L, 17L])
}
