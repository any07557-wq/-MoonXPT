///|
pub fn VariableMetadata::new(
  name : String,
  kind : VariableType,
  width : Int32,
  position : Int32,
  label~ : Bytes = b"",
  number~ : Int32 = 1,
) -> VariableMetadata raise XptError {
  {
    name: encode_text(name, Ascii),
    label,
    kind,
    width,
    position,
    number,
    hash: 0,
    format: { name: b"", width: 0, decimals: 0, justification: 0, },
    informat: { name: b"", width: 0, decimals: 0, justification: 0, },
  }
}

///|
pub fn DatasetMetadata::new(
  name : String,
  variables : Array[VariableMetadata],
  label~ : Bytes = b"",
) -> DatasetMetadata raise XptError {
  let row_width = validate_layout(variables, Limits::default())
  {
    name: encode_text(name, Ascii),
    label,
    variables,
    row_width,
    dataset_type: b"",
    version: b"0.1",
    os: b"MOONXPT",
    created: b"",
    modified: b"",
    descriptor_size: 140,
  }
}

///|
pub fn LibraryMetadata::new() -> LibraryMetadata {
  { version: b"0.1", os: b"MOONXPT", created: b"", modified: b"", }
}

///|
fn fixed(
  builder : ByteBuilder,
  at : Int32,
  width : Int32,
  value : Bytes,
) -> Unit raise XptError {
  if value.length() > width {
    fail("schema", "fixed metadata field exceeds \{width} bytes")
  }
  builder.put(at, value)
}

///|
fn timestamp(bytes : Bytes, fallback : Bytes) -> Bytes raise XptError {
  let raw = if bytes.is_empty() || is_spaces(bytes) { fallback } else { bytes }
  if raw.length() != 16 {
    fail("schema", "timestamp must be exactly DATETIME16 bytes")
  }
  for i in [0, 1, 5, 6, 8, 9, 11, 12, 14, 15] {
    if raw[i] < b'0' || raw[i] > b'9' {
      fail("schema", "invalid timestamp digit")
    }
  }
  if raw[7] != b':' || raw[10] != b':' || raw[13] != b':' {
    fail("schema", "invalid timestamp separators")
  }
  let month = decode_text(field(raw, 2, 3), Ascii)
  if ![
      "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV",
      "DEC",
    ].contains(month) {
    fail("schema", "invalid timestamp month")
  }
  if decimal_field(raw, 0, 2) < 1 ||
    decimal_field(raw, 0, 2) > 31 ||
    decimal_field(raw, 8, 2) > 23 ||
    decimal_field(raw, 11, 2) > 59 ||
    decimal_field(raw, 14, 2) > 59 {
    fail("schema", "timestamp component out of range")
  }
  raw
}

///|
pub fn encode_library(
  meta : LibraryMetadata,
  options : WriteOptions,
) -> Bytes raise XptError {
  ignore(validate_layout([], options.limits))
  let a = ByteBuilder::new(80)
  a.put(0, b"SAS     SAS     SASLIB  ")
  fixed(a, 24, 8, meta.version)
  fixed(a, 32, 8, meta.os)
  a.put(64, timestamp(meta.created, options.timestamp))
  let b = ByteBuilder::new(80)
  b.put(0, timestamp(meta.modified, options.timestamp))
  header("LIBRARY") + a.bytes() + b.bytes()
}

///|
fn validate_format(f : DisplayFormat) -> Unit raise XptError {
  if f.name.length() > 8 ||
    f.width < 0 ||
    f.width > 65535 ||
    f.decimals < 0 ||
    f.decimals > 65535 ||
    f.justification < 0 ||
    f.justification > 1 {
    fail("schema", "invalid format/informat attributes")
  }
}

///|
pub fn encode_dataset(
  meta : DatasetMetadata,
  options : WriteOptions,
) -> Bytes raise XptError {
  if !valid_name(meta.name) {
    fail("schema", "invalid V5 dataset name")
  }
  if validate_layout(meta.variables, options.limits) != meta.row_width {
    fail("schema", "row width disagrees with storage positions")
  }
  let first = ByteBuilder::new(80)
  first.put(0, header("MEMBER"))
  first.put(65, b"160")
  first.put(74, b"0140")
  let a = ByteBuilder::new(80)
  a.put(0, b"SAS     ")
  fixed(a, 8, 8, meta.name)
  a.put(16, b"SASDATA ")
  fixed(a, 24, 8, meta.version)
  fixed(a, 32, 8, meta.os)
  a.put(64, timestamp(meta.created, options.timestamp))
  let b = ByteBuilder::new(80)
  b.put(0, timestamp(meta.modified, options.timestamp))
  fixed(b, 32, 40, meta.label)
  fixed(b, 72, 8, meta.dataset_type)
  let nh = ByteBuilder::new(80)
  nh.put(0, header("NAMESTR"))
  nh.put(
    54,
    encode_text(meta.variables.length().to_string().pad_start(4, '0'), Ascii),
  )
  let out : Array[Byte] = []
  for
    block in [
      first.bytes(),
      header("DSCRPTR"),
      a.bytes(),
      b.bytes(),
      nh.bytes(),
    ] {
    out.push_iter(block.iter())
  }
  for v in meta.variables {
    validate_format(v.format)
    validate_format(v.informat)
    if v.informat.justification != 0 {
      fail("schema", "V5 has no informat justification field")
    }
    let n = ByteBuilder::new(140, fill=b'\x00')
    n.u16(0, if v.kind == Number { 1 } else { 2 })
    n.u16(2, v.hash)
    n.u16(4, v.width)
    n.u16(6, v.number)
    // Text portions use blank padding, while reserved binary fields are zero.
    n.put(8, Bytes::make(56, b' '))
    n.put(72, Bytes::make(8, b' '))
    fixed(n, 8, 8, v.name)
    fixed(n, 16, 40, v.label)
    fixed(n, 56, 8, v.format.name)
    n.u16(64, v.format.width)
    n.u16(66, v.format.decimals)
    n.u16(68, v.format.justification)
    fixed(n, 72, 8, v.informat.name)
    n.u16(80, v.informat.width)
    n.u16(82, v.informat.decimals)
    n.u32(84, v.position.to_int64())
    out.push_iter(n.bytes().iter())
  }
  out.push_iter(
    Bytes::make(padding(140 * meta.variables.length()), b' ').iter(),
  )
  out.push_iter(header("OBS").iter())
  Bytes::from_array(out)
}
