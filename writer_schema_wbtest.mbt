///|
test "deterministic schema encoding and metadata constraints" {
  let variable = VariableMetadata::new(
    "NUMBER",
    Number,
    8,
    0,
    label=b"Numeric value",
  )
  let ds = DatasetMetadata::new("SAMPLE", [variable], label=b"Dataset label")
  let options = WriteOptions::default()
  let encoded = encode_library(LibraryMetadata::new(), options) +
    encode_dataset(ds, options)
  assert_eq(
    encoded,
    encode_library(LibraryMetadata::new(), options) +
    encode_dataset(ds, options),
  )
  let input = input_from_bytes(encoded, chunk_size=7)
  assert_eq(read_library(input).created, options.timestamp)
  let decoded = read_dataset(input, input.required(80), Limits::default())
  assert_eq(text_field(decoded.name, Ascii), "SAMPLE")
  assert_eq(text_field(decoded.label, Ascii), "Dataset label")
  assert_eq(decoded.row_width, 8)
  assert_eq(text_field(decoded.variables[0].label, Ascii), "Numeric value")
  let bad = { ..ds, label: Bytes::make(41, b'x'), }
  try encode_dataset(bad, options) catch {
    XptError(d) => assert_eq(d.kind, "schema")
  } noraise {
    _ => assert_true(false)
  }
  try
    encode_dataset(
      {
        ..ds,
        variables: [variable, { ..variable, position: 4, name: b"SECOND", }],
        row_width: 12,
      },
      options,
    )
  catch {
    XptError(d) => assert_eq(d.kind, "schema")
  } noraise {
    _ => assert_true(false)
  }
}
