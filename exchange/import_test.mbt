///|
test "typed missing tokens, finite decimals and explicit empty policy" {
  let schema = @moonxpt.DatasetMetadata::new("TEST", [
    @moonxpt.VariableMetadata::new("N", @moonxpt.Number, 8, 0),
    @moonxpt.VariableMetadata::new("C", @moonxpt.Text, 20, 8, number=2),
  ])
  assert_eq(@exchange.import_cells(schema, [".A", ".A"], @moonxpt.Ascii), [
    @moonxpt.Numeric(@moonxpt.Missing(b'A')),
    @moonxpt.Character(b".A"),
  ])
  for raw in ["", "NaN", "Infinity", "1,2", " 1", "1 ", ".a", "1e999", "1e-999"] {
    try @exchange.import_cells(schema, [raw, ""], @moonxpt.Ascii) catch {
      _ => ()
    } noraise {
      _ => assert_true(false)
    }
  }
  assert_eq(
    @exchange.import_cells(
      schema,
      ["", ""],
      @moonxpt.Ascii,
      numeric_empty_missing=true,
    ),
    [@moonxpt.Numeric(@moonxpt.Missing(b'.')), @moonxpt.Character(b"")],
  )
  assert_eq(
    @exchange.import_cells(schema, ["-1.25e+2", "  x  "], @moonxpt.Ascii),
    [@moonxpt.Numeric(@moonxpt.Finite(-125.0)), @moonxpt.Character(b"  x  ")],
  )
}

///|
test "metadata contract and unknown version validation" {
  let ds = @moonxpt.DatasetMetadata::new("TEST", [
    @moonxpt.VariableMetadata::new("X", @moonxpt.Number, 8, 0),
  ])
  let json = @exchange.metadata_json(
    @moonxpt.LibraryMetadata::new(),
    ds,
    @moonxpt.Ascii,
    1L,
  )
  let parsed = @exchange.parse_metadata(json.stringify())
  assert_eq(parsed.row_count, 1L)
  assert_eq(parsed.dataset.row_width, 8)
  let bad = json
    .stringify()
    .replace_all(old="\"schema_version\":1", new="\"schema_version\":2")
  try @exchange.parse_metadata(bad) catch {
    _ => ()
  } noraise {
    _ => assert_true(false)
  }
}
