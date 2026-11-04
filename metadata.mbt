///|
/// Attach only known context; offsets refer to the beginning of the failed field.
fn[T] at_context(
  offset : Int64,
  action : () -> T raise,
  dataset? : String,
  variable? : String,
  row? : Int64,
) -> T raise {
  action() catch {
    XptError(d) =>
      raise XptError({
        ..d,
        offset: Some(d.offset.unwrap_or(offset)),
        dataset: match d.dataset {
          Some(_) => d.dataset
          None => dataset
        },
        variable: match d.variable {
          Some(_) => d.variable
          None => variable
        },
        row: match d.row {
          Some(_) => d.row
          None => row
        },
      })
    e => raise e
  }
}

///|
pub fn read_library(input : Input) -> LibraryMetadata raise {
  let start = input.offset()
  at_context(start, () => {
    let h = input.required(80)
    if header_is(h, "LIBV8") {
      fail("version", "XPORT V8 is not supported", offset=start)
    }
    expect_header(h, "LIBRARY", start)
    let a = input.required(80)
    let b = input.required(80)
    if field(a, 0, 24) != b"SAS     SAS     SASLIB  " {
      fail("structure", "invalid V5 library real header", offset=start + 80L)
    }
    {
      version: field(a, 24, 8),
      os: field(a, 32, 8),
      created: field(a, 64, 16),
      modified: field(b, 0, 16),
    }
  })
}

///|
pub fn valid_name(raw : Bytes) -> Bool {
  let name = trim_field(raw)
  if name.is_empty() || name.length() > 8 {
    return false
  }
  for i = 0; i < name.length(); i = i + 1 {
    let c = name[i]
    if !(c == b'_' ||
      (c >= b'A' && c <= b'Z') ||
      (c >= b'a' && c <= b'z') ||
      (i > 0 && c >= b'0' && c <= b'9')) {
      return false
    }
  }
  true
}

///|
/// Schema layout validation checks before allocating row buffers.
pub fn validate_layout(
  variables : Array[VariableMetadata],
  limits : Limits,
) -> Int32 raise XptError {
  if limits.max_variables < 0 ||
    limits.max_variables > 9999 ||
    limits.max_row_bytes < 0 ||
    limits.max_row_bytes > 16777216 ||
    limits.max_datasets < 0 ||
    limits.max_rows < 0L ||
    limits.max_input_bytes < 0L {
    fail("limit", "invalid configured resource limit")
  }
  if variables.length() > limits.max_variables {
    fail("limit", "variable count exceeds limit")
  }
  let seen : Map[String, Bool] = Map([])
  let mut end = 0
  for v in variables {
    if !valid_name(v.name) {
      fail("schema", "invalid V5 variable name")
    }
    let name = text_field(v.name, Ascii).to_upper()
    if seen.contains(name) {
      fail("schema", "duplicate variable name", variable=name)
    }
    seen[name] = true
    if v.width < 1 ||
      (v.kind == Number && (v.width < 2 || v.width > 8)) ||
      (v.kind == Text && v.width > 200) {
      fail("schema", "invalid V5 variable width", variable=name)
    }
    if v.position < 0 ||
      v.position > limits.max_row_bytes ||
      v.width > limits.max_row_bytes - v.position {
      fail("limit", "field position exceeds row limit", variable=name)
    }
    end = end.max(v.position + v.width)
  }
  let sorted = variables.copy()
  sorted.sort_by((a, b) => a.position.compare(b.position))
  let mut prior_end = 0
  for v in sorted {
    if v.position < prior_end {
      fail("schema", "overlapping variable storage")
    }
    prior_end = v.position + v.width
  }
  end
}

///|
fn parse_variable(bytes : Bytes) -> VariableMetadata raise XptError {
  let typ = u16be(bytes, 0)
  if typ != 1 && typ != 2 {
    fail("schema", "unknown variable type")
  }
  let position = u32be(bytes, 84)
  if position > 16777216L {
    fail("limit", "field position exceeds maximum row allocation")
  }
  {
    name: field(bytes, 8, 8),
    label: field(bytes, 16, 40),
    kind: if typ == 1 {
      Number
    } else {
      Text
    },
    width: u16be(bytes, 4),
    number: u16be(bytes, 6),
    hash: u16be(bytes, 2),
    position: position.to_int(),
    format: {
      name: field(bytes, 56, 8),
      width: u16be(bytes, 64),
      decimals: u16be(bytes, 66),
      justification: u16be(bytes, 68),
    },
    informat: {
      name: field(bytes, 72, 8),
      width: u16be(bytes, 80),
      decimals: u16be(bytes, 82),
      justification: 0,
    },
  }
}

///|
/// first is a complete physical MEMBER record, already consumed from input.
pub fn read_dataset(
  input : Input,
  first : Bytes,
  limits : Limits,
) -> DatasetMetadata raise {
  let start = input.offset() - 80L
  at_context(start, () => {
    expect_header(first, "MEMBER", start)
    let descriptor_size = decimal_field(first, 74, 4)
    if descriptor_size != 136 && descriptor_size != 140 {
      fail("structure", "NAMESTR size must be 136 or 140")
    }
    if decimal_field(first, 65, 3) != 160 {
      fail("structure", "unsupported member header size")
    }
    expect_header(input.required(80), "DSCRPTR", start + 80L)
    let a = input.required(80)
    if field(a, 0, 8) != b"SAS     " || field(a, 16, 8) != b"SASDATA " {
      fail("structure", "invalid member real header")
    }
    let name = field(a, 8, 8)
    if !valid_name(name) {
      fail("schema", "invalid V5 dataset name")
    }
    let b = input.required(80)
    let nh = input.required(80)
    expect_header(nh, "NAMESTR", start + 320L)
    let count = decimal_field(nh, 54, 4)
    if count > limits.max_variables || count > 9999 {
      fail("limit", "variable count exceeds limit")
    }
    let vars : Array[VariableMetadata] = []
    for i = 0; i < count; i = i + 1 {
      let offset = input.offset()
      vars.push(
        at_context(
          offset,
          () => parse_variable(input.required(descriptor_size)),
          dataset=text_field(name, Ascii),
        ),
      )
    }
    let pad_at = input.offset()
    if !is_spaces(input.required(padding(count * descriptor_size))) {
      fail("structure", "nonblank descriptor padding", offset=pad_at)
    }
    let obs_at = input.offset()
    expect_header(input.required(80), "OBS", obs_at)
    let row_width = validate_layout(vars, limits)
    {
      name,
      label: field(b, 32, 40),
      dataset_type: field(b, 72, 8),
      version: field(a, 24, 8),
      os: field(a, 32, 8),
      created: field(a, 64, 16),
      modified: field(b, 0, 16),
      descriptor_size,
      variables: vars,
      row_width,
    }
  })
}
