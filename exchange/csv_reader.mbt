///|
/// A bounded UTF-8 CSV record parser. Source owns its file lifecycle.
pub struct CsvReader {
  read : (Int32) -> Bytes raise
  max_record : Int32
  max_columns : Int32
  max_input : Int64
  mut buffer : Bytes
  mut at : Int32
  mut offset : Int64
  mut received : Int64
  mut record : Int64
}

///|
pub fn CsvReader::offset(self : CsvReader) -> Int64 {
  self.offset
}

///|
pub fn CsvReader::new(
  read : (Int32) -> Bytes raise,
  max_record_bytes~ : Int32 = 16777216,
  max_columns~ : Int32 = 9999,
  max_input_bytes~ : Int64 = 1099511627776L,
) -> CsvReader raise @xpt.XptError {
  if max_record_bytes < 1 ||
    max_record_bytes > 16777216 ||
    max_columns < 0 ||
    max_columns > 9999 ||
    max_input_bytes < 0L {
    @xpt.fail("limit", "invalid CSV resource limits")
  }
  {
    read,
    max_record: max_record_bytes,
    max_columns,
    max_input: max_input_bytes,
    buffer: b"",
    at: 0,
    offset: 0L,
    received: 0L,
    record: 0L,
  }
}

///|
fn CsvReader::byte(self : CsvReader) -> Byte? raise {
  if self.at == self.buffer.length() {
    let wanted = (self.max_input - self.received).min(4096L).max(1L).to_int()
    let chunk = (self.read)(wanted)
    if chunk.length() > wanted {
      @xpt.fail("io", "CSV source exceeded requested bytes", offset=self.offset)
    }
    if chunk.is_empty() {
      return None
    }
    if chunk.length().to_int64() > self.max_input - self.received {
      @xpt.fail("limit", "CSV input byte limit exceeded", offset=self.offset)
    }
    self.buffer = chunk
    self.at = 0
    self.received = self.received + chunk.length().to_int64()
  }
  let byte = self.buffer[self.at]
  self.at = self.at + 1
  self.offset = self.offset + 1L
  Some(byte)
}

///|
fn CsvReader::cell(
  self : CsvReader,
  cells : Array[String],
  raw : Array[Byte],
) -> Unit raise {
  if cells.length() >= self.max_columns.max(1) {
    @xpt.fail(
      "limit",
      "CSV column limit exceeded",
      offset=self.offset,
      row=self.record,
    )
  }
  let text = @utf8.decode(Bytes::from_array(raw)[:], ignore_bom=false) catch {
    _ =>
      @xpt.fail(
        "encoding",
        "CSV field is not valid UTF-8",
        offset=self.offset,
        row=self.record,
      )
  }
  if self.record == 0L && cells.is_empty() && text.has_prefix("\uFEFF") {
    @xpt.fail("csv", "CSV BOM is not permitted", offset=0L)
  }
  cells.push(text)
  raw.clear()
}

///|
pub fn CsvReader::next_record(self : CsvReader) -> Array[String]? raise {
  let cells : Array[String] = []
  let raw : Array[Byte] = []
  let start = self.offset
  let mut state = 0 // 0 start, 1 unquoted, 2 quoted, 3 closing quote
  let mut started = false
  while true {
    let byte = self.byte()
    if byte is None {
      if state == 2 {
        @xpt.fail(
          "csv",
          "unterminated quoted field",
          offset=self.offset,
          row=self.record,
        )
      }
      if !started {
        return None
      }
      self.cell(cells, raw)
      self.record = self.record + 1L
      return Some(cells)
    }
    let c = byte.unwrap()
    started = true
    if self.offset - start > self.max_record.to_int64() {
      @xpt.fail(
        "limit",
        "CSV record exceeds byte limit",
        offset=self.offset,
        row=self.record,
      )
    }
    if state == 2 {
      if c == b'"' {
        state = 3
      } else {
        raw.push(c)
      }
      continue
    }
    if state == 3 && c == b'"' {
      raw.push(c)
      state = 2
      continue
    }
    if c == b',' {
      self.cell(cells, raw)
      state = 0
      continue
    }
    if c == b'\n' || c == b'\r' {
      if c == b'\r' && self.byte() != Some(b'\n') {
        @xpt.fail(
          "csv",
          "bare CR outside quoted field",
          offset=self.offset,
          row=self.record,
        )
      }
      self.cell(cells, raw)
      self.record = self.record + 1L
      return Some(cells)
    }
    if state == 3 {
      @xpt.fail(
        "csv",
        "unexpected byte after closing quote",
        offset=self.offset - 1L,
        row=self.record,
      )
    }
    if c == b'"' {
      if state != 0 {
        @xpt.fail(
          "csv",
          "quote inside unquoted field",
          offset=self.offset - 1L,
          row=self.record,
        )
      }
      state = 2
    } else {
      raw.push(c)
      state = 1
    }
  } nobreak {
    None
  }
}

///|
/// Numeric syntax is explicit ASCII decimal with optional exponent, no whitespace.
fn decimal_syntax(text : String) -> Bool {
  let raw = @utf8.encode(text[:])
  let n = raw.length()
  let mut i = 0
  if i < n && (raw[i] == b'+' || raw[i] == b'-') {
    i = i + 1
  }
  let mut digits = 0
  while i < n && raw[i] >= b'0' && raw[i] <= b'9' {
    i = i + 1
    digits = digits + 1
  }
  if i < n && raw[i] == b'.' {
    i = i + 1
    while i < n && raw[i] >= b'0' && raw[i] <= b'9' {
      i = i + 1
      digits = digits + 1
    }
  }
  if digits == 0 {
    return false
  }
  if i < n && (raw[i] == b'e' || raw[i] == b'E') {
    i = i + 1
    if i < n && (raw[i] == b'+' || raw[i] == b'-') {
      i = i + 1
    }
    let start = i
    while i < n && raw[i] >= b'0' && raw[i] <= b'9' {
      i = i + 1
    }
    if i == start {
      return false
    }
  }
  i == n
}

///|
pub fn import_cells(
  meta : @xpt.DatasetMetadata,
  cells : Array[String],
  encoding : @xpt.Encoding,
  numeric_empty_missing~ : Bool = false,
) -> Array[@xpt.Value] raise {
  if cells.length() != meta.variables.length() {
    @xpt.fail("csv", "CSV column count does not match metadata")
  }
  let values : Array[@xpt.Value] = []
  for i = 0; i < cells.length(); i = i + 1 {
    let text = cells[i]
    let v = meta.variables[i]
    values.push(
      if v.kind == @xpt.Text {
        @xpt.Character(@xpt.encode_text(text, encoding))
      } else {
        let raw = @utf8.encode(text[:])
        let numeric = if text == "." ||
          (text.is_empty() && numeric_empty_missing) {
          @xpt.Missing(b'.')
        } else if raw.length() == 2 &&
          raw[0] == b'.' &&
          @xpt.valid_missing(raw[1]) &&
          raw[1] != b'.' {
          @xpt.Missing(raw[1])
        } else {
          if !decimal_syntax(text) {
            @xpt.fail(
              "numeric",
              "invalid or empty numeric CSV field",
              variable=@xpt.text_field(v.name, @xpt.Ascii),
            )
          }
          let n = @string.parse_double(text[:]) catch {
            _ => @xpt.fail("numeric", "cannot parse numeric CSV field")
          }
          if n.is_nan() || n.is_inf() {
            @xpt.fail("numeric", "CSV value is not finite")
          }
          @xpt.Finite(n)
        }
        @xpt.Numeric(numeric)
      },
    )
  }
  values
}
