///|
pub struct ExchangeMetadata {
  library : @xpt.LibraryMetadata
  dataset : @xpt.DatasetMetadata
  encoding : @xpt.Encoding
  row_count : Int64
}

///|
fn property(json : Json, key : String) -> Json raise @xpt.XptError {
  match json {
    Object(fields) =>
      fields
      .get(key)
      .unwrap_or_else(() => {
        @xpt.fail("metadata", "missing metadata field: \{key}")
      })
    _ => @xpt.fail("metadata", "expected JSON object")
  }
}

///|
fn text(json : Json, key : String) -> String raise @xpt.XptError {
  match property(json, key) {
    String(s) => s
    _ => @xpt.fail("metadata", "expected string: \{key}")
  }
}

///|
fn integer(json : Json, key : String, max : Int64) -> Int64 raise @xpt.XptError {
  match property(json, key) {
    Number(n, ..) => {
      if n.is_nan() ||
        n.is_inf() ||
        n < 0.0 ||
        n > max.to_double() ||
        n > 9007199254740991.0 ||
        n.floor() != n {
        @xpt.fail("metadata", "invalid integer: \{key}")
      }
      n.to_int64()
    }
    _ => @xpt.fail("metadata", "expected integer: \{key}")
  }
}

///|
fn decode_format(
  json : Json,
  encoding : @xpt.Encoding,
) -> @xpt.DisplayFormat raise @xpt.XptError {
  {
    name: @xpt.encode_text(text(json, "name"), encoding),
    width: integer(json, "width", 65535L).to_int(),
    decimals: integer(json, "decimals", 65535L).to_int(),
    justification: integer(json, "justification", 1L).to_int(),
  }
}

///|
fn decode_variable(
  json : Json,
  encoding : @xpt.Encoding,
  limits : @xpt.Limits,
) -> @xpt.VariableMetadata raise @xpt.XptError {
  let kind = match text(json, "type") {
    "numeric" => @xpt.Number
    "character" => @xpt.Text
    _ => @xpt.fail("metadata", "unknown variable type")
  }
  {
    name: @xpt.encode_text(text(json, "name"), @xpt.Ascii),
    label: @xpt.encode_text(text(json, "label"), encoding),
    kind,
    width: integer(json, "width", 200L).to_int(),
    position: integer(json, "position", limits.max_row_bytes.to_int64()).to_int(),
    number: integer(json, "number", 65535L).to_int(),
    hash: integer(json, "hash", 65535L).to_int(),
    format: decode_format(property(json, "format"), encoding),
    informat: decode_format(property(json, "informat"), encoding),
  }
}

///|
pub fn parse_metadata(
  source : String,
  limits~ : @xpt.Limits = @xpt.Limits::default(),
) -> ExchangeMetadata raise {
  let json = @json.parse(source[:]) catch {
    _ => @xpt.fail("metadata", "invalid metadata JSON")
  }
  if integer(json, "schema_version", 2147483647L) != 1L {
    @xpt.fail("metadata", "unsupported metadata schema_version")
  }
  if property(json, "csv") != csv_contract() {
    @xpt.fail("metadata", "unsupported CSV contract")
  }
  let encoding = parse_encoding(text(json, "encoding"))
  let lib = property(json, "library")
  let library : @xpt.LibraryMetadata = {
    version: @xpt.encode_text(text(lib, "version"), @xpt.Ascii),
    os: @xpt.encode_text(text(lib, "os"), @xpt.Ascii),
    created: @xpt.encode_text(text(lib, "created"), @xpt.Ascii),
    modified: @xpt.encode_text(text(lib, "modified"), @xpt.Ascii),
  }
  let ds = property(json, "dataset")
  let variables = match property(ds, "variables") {
    Array(values) => values
    _ => @xpt.fail("metadata", "variables must be an array")
  }
  if variables.length() > limits.max_variables {
    @xpt.fail("limit", "metadata variable count exceeds limit")
  }
  let cols : Array[@xpt.VariableMetadata] = []
  for v in variables {
    cols.push(decode_variable(v, encoding, limits))
  }
  let size = integer(ds, "descriptor_size", 140L).to_int()
  if size != 136 && size != 140 {
    @xpt.fail("metadata", "invalid descriptor_size")
  }
  let dataset : @xpt.DatasetMetadata = {
    name: @xpt.encode_text(text(ds, "name"), @xpt.Ascii),
    label: @xpt.encode_text(text(ds, "label"), encoding),
    dataset_type: @xpt.encode_text(text(ds, "dataset_type"), encoding),
    version: @xpt.encode_text(text(ds, "version"), @xpt.Ascii),
    os: @xpt.encode_text(text(ds, "os"), @xpt.Ascii),
    created: @xpt.encode_text(text(ds, "created"), @xpt.Ascii),
    modified: @xpt.encode_text(text(ds, "modified"), @xpt.Ascii),
    descriptor_size: size,
    variables: cols,
    row_width: integer(ds, "row_width", limits.max_row_bytes.to_int64()).to_int(),
  }
  let row_count = integer(json, "row_count", limits.max_rows)
  if dataset.row_width == 0 && row_count != 0L {
    @xpt.fail("metadata", "zero-column dataset cannot have observations")
  }
  let options = { ..@xpt.WriteOptions::default(), limits, }
  ignore(@xpt.encode_library(library, options))
  ignore(@xpt.encode_dataset(dataset, options))
  { library, dataset, encoding, row_count, }
}
