///|
pub struct Writer {
  output : Output
  options : WriteOptions
  mut active : DatasetMetadata?
  mut start : Int64
  mut rows : Int64
  mut count : Int32
  mut finished : Bool
  mut failed : Bool
  seen : Map[String, Bool]
}

///|
pub fn Writer::new(
  output : Output,
  library~ : LibraryMetadata = LibraryMetadata::new(),
  options~ : WriteOptions = WriteOptions::default(),
) -> Writer raise {
  if options.max_output_bytes < 0L {
    fail("limit", "negative output limit")
  }
  output.limit = output.limit.min(options.max_output_bytes)
  output.put(encode_library(library, options))
  {
    output,
    options,
    active: None,
    start: 0L,
    rows: 0L,
    count: 0,
    finished: false,
    failed: false,
    seen: Map([]),
  }
}

///|
fn Writer::check(self : Writer) -> Unit raise XptError {
  if self.failed || self.finished {
    fail(
      "state",
      "writer is failed or already finished",
      offset=self.output.offset(),
    )
  }
}

///|
pub fn Writer::end_dataset(self : Writer) -> Unit raise {
  self.check()
  errdefer {
    self.failed = true
  }
  if self.active is Some(_) {
    let pad = ((80L - (self.output.offset() - self.start) % 80L) % 80L).to_int()
    self.output.put(Bytes::make(pad, b' '))
    self.active = None
  }
}

///|
pub fn Writer::begin_dataset(
  self : Writer,
  meta : DatasetMetadata,
) -> Unit raise {
  self.check()
  errdefer {
    self.failed = true
  }
  if self.count >= self.options.limits.max_datasets {
    fail("limit", "member count exceeds write limit")
  }
  let key = text_field(meta.name, Ascii).to_upper()
  if self.seen.contains(key) {
    fail("schema", "duplicate dataset name", dataset=key)
  }
  let snapshot = { ..meta, variables: meta.variables.copy(), }
  let bytes = encode_dataset(snapshot, self.options)
  self.end_dataset()
  self.output.put(bytes)
  self.count = self.count + 1
  self.seen[key] = true
  self.active = Some(snapshot)
  self.start = self.output.offset()
  self.rows = 0L
}

///|
pub fn encode_observation(
  meta : DatasetMetadata,
  values : Array[Value],
) -> Bytes raise XptError {
  if values.length() != meta.variables.length() {
    fail("schema", "row column count mismatch")
  }
  let b = ByteBuilder::new(meta.row_width)
  for i = 0; i < values.length(); i = i + 1 {
    let v = meta.variables[i]
    let raw = match (v.kind, values[i]) {
      (Number, Numeric(n)) => encode_numeric(n, v.width)
      (Text, Character(raw)) => {
        if raw.length() > v.width {
          fail(
            "width",
            "character field exceeds encoded byte width",
            variable=text_field(v.name, Ascii),
          )
        }
        raw
      }
      _ =>
        fail(
          "schema",
          "value type disagrees with variable",
          variable=text_field(v.name, Ascii),
        )
    }
    b.put(v.position, raw)
  }
  b.bytes()
}

///|
pub fn Writer::write_row(self : Writer, values : Array[Value]) -> Unit raise {
  self.check()
  errdefer {
    self.failed = true
  }
  let meta = self.active.unwrap_or_else(() => {
    fail("state", "begin_dataset is required")
  })
  if meta.row_width == 0 {
    fail("schema", "zero-column datasets cannot contain observations")
  }
  if self.rows >= self.options.limits.max_rows {
    fail("limit", "row count exceeds write limit")
  }
  let raw = at_context(
    self.output.offset(),
    () => encode_observation(meta, values),
    dataset=text_field(meta.name, Ascii),
    row=self.rows,
  )
  self.output.put(raw)
  self.rows = self.rows + 1L
}

///|
/// Raw rows retain numerical low bits and full character bytes. Validate before use.
pub fn Writer::write_raw(self : Writer, raw : Bytes) -> Unit raise {
  self.check()
  errdefer {
    self.failed = true
  }
  let meta = self.active.unwrap_or_else(() => {
    fail("state", "begin_dataset is required")
  })
  if meta.row_width == 0 || self.rows >= self.options.limits.max_rows {
    fail("limit", "invalid raw row or row limit")
  }
  ignore(decode_observation(meta, raw, self.rows, self.output.offset()))
  self.output.put(raw)
  self.rows = self.rows + 1L
}

///|
pub fn Writer::finish(self : Writer) -> Unit raise {
  self.check()
  self.end_dataset()
  self.finished = true
}
