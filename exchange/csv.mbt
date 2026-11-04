///|
/// Encode one row without changing data or trimming spaces.
pub fn csv_record(cells : Array[String]) -> Bytes {
  let fields : Array[String] = []
  for text in cells {
    if text.contains_char(',') ||
      text.contains_char('"') ||
      text.contains_char('\r') ||
      text.contains_char('\n') {
      fields.push("\"" + text.replace_all(old="\"", new="\"\"") + "\"")
    } else {
      fields.push(text)
    }
  }
  @utf8.encode((fields.join(",") + "\n")[:])
}

///|
pub fn row_cells(
  row : @xpt.Observation,
  encoding : @xpt.Encoding,
) -> Array[String] raise @xpt.XptError {
  let cells : Array[String] = []
  for v in row.values {
    cells.push(
      match v {
        @xpt.Numeric(@xpt.Finite(n)) => n.to_string()
        @xpt.Numeric(@xpt.Missing(tag)) => @xpt.missing_token(tag)
        @xpt.Character(raw) => @xpt.decode_text(raw, encoding)
      },
    )
  }
  cells
}

///|
pub fn csv_header(meta : @xpt.DatasetMetadata) -> Bytes raise @xpt.XptError {
  let names : Array[String] = []
  for v in meta.variables {
    names.push(@xpt.text_field(v.name, @xpt.Ascii))
  }
  csv_record(names)
}

///|
pub fn csv_contract() -> Json {
  {
    "header": true,
    "delimiter": ",",
    "quote": "\"",
    "newline": "LF",
    "bom": false,
    "numeric_empty": "error",
    "character_spaces": "preserve",
  }
}

///|
pub fn metadata_json(
  library : @xpt.LibraryMetadata,
  dataset : @xpt.DatasetMetadata,
  encoding : @xpt.Encoding,
  rows : Int64,
) -> Json raise @xpt.XptError {
  {
    "schema_version": 1,
    "encoding": encoding_name(encoding),
    "csv": csv_contract(),
    "library": library_json(library),
    "dataset": dataset_json(dataset, encoding),
    "row_count": integer_json(rows),
  }
}
