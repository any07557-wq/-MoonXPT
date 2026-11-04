///|
/// Explicit encoding; V5 does not identify its text encoding.
pub(all) enum Encoding {
  Ascii
  Windows1252
} derive(Eq, @debug.Debug)

///|
/// System missing is '.', tagged values are '_' or 'A' through 'Z'.
pub(all) enum NumericValue {
  Finite(Double)
  Missing(Byte)
} derive(Eq, @debug.Debug)

///|
/// Character storage retains every byte, including trailing spaces.
pub(all) enum Value {
  Numeric(NumericValue)
  Character(Bytes)
} derive(Eq, @debug.Debug)

///|
pub(all) enum VariableType {
  Number
  Text
} derive(Eq, @debug.Debug)

///|
pub(all) struct DisplayFormat {
  name : Bytes
  width : Int32
  decimals : Int32
  justification : Int32
} derive(Eq, @debug.Debug)

///|
pub(all) struct VariableMetadata {
  name : Bytes
  label : Bytes
  kind : VariableType
  width : Int32
  position : Int32
  number : Int32
  hash : Int32
  format : DisplayFormat
  informat : DisplayFormat
} derive(Eq, @debug.Debug)

///|
pub(all) struct LibraryMetadata {
  version : Bytes
  os : Bytes
  created : Bytes
  modified : Bytes
} derive(Eq, @debug.Debug)

///|
pub(all) struct DatasetMetadata {
  name : Bytes
  label : Bytes
  dataset_type : Bytes
  version : Bytes
  os : Bytes
  created : Bytes
  modified : Bytes
  descriptor_size : Int32
  variables : Array[VariableMetadata]
  row_width : Int32
} derive(Eq, @debug.Debug)

///|
/// Reject is loss-aware. TrimPadding is explicitly lossy for short blank rows.
pub(all) enum TailPolicy {
  Reject
  TrimPadding
} derive(Eq, @debug.Debug)

///|
pub(all) struct Limits {
  max_variables : Int32
  max_row_bytes : Int32
  max_datasets : Int32
  max_rows : Int64
  max_input_bytes : Int64
} derive(Eq, @debug.Debug)

///|
pub fn Limits::default() -> Limits {
  {
    max_variables: 9999,
    max_row_bytes: 16 * 1024 * 1024,
    max_datasets: 1024,
    max_rows: 1000000000L,
    max_input_bytes: 1099511627776L,
  }
}

///|
pub(all) struct ReadOptions {
  limits : Limits
  tail_policy : TailPolicy
  row_hints : Map[String, Int64]
} derive(@debug.Debug)

///|
pub fn ReadOptions::default() -> ReadOptions {
  { limits: Limits::default(), tail_policy: Reject, row_hints: {}, }
}

///|
pub(all) struct WriteOptions {
  limits : Limits
  timestamp : Bytes
} derive(@debug.Debug)

///|
pub fn WriteOptions::default() -> WriteOptions {
  { limits: Limits::default(), timestamp: b"01JAN00:00:00:00", }
}

///|
pub(all) struct Diagnostic {
  kind : String
  offset : Int64?
  dataset : String?
  row : Int64?
  variable : String?
  reason : String
} derive(Eq, @debug.Debug)

///|
pub(all) suberror XptError {
  XptError(Diagnostic)
} derive(@debug.Debug)

///|
pub fn[T] fail(
  kind : String,
  reason : String,
  offset? : Int64,
  dataset? : String,
  row? : Int64,
  variable? : String,
) -> T raise XptError {
  raise XptError({ kind, reason, offset, dataset, row, variable, })
}

///| Callbacks return short chunks (at most requested); empty means final EOF.

///|
/// The caller owns the underlying source and must close it after cancellation.
pub struct Input {
  read : (Int32) -> Bytes raise
  mut offset : Int64
  limit : Int64
}

///|
pub fn Input::new(
  read : (Int32) -> Bytes raise,
  max_bytes~ : Int64 = 1099511627776L,
) -> Input raise XptError {
  if max_bytes < 0 {
    fail("limit", "negative input limit")
  }
  { read, offset: 0L, limit: max_bytes, }
}

///|
pub fn Input::offset(self : Input) -> Int64 {
  self.offset
}

///|
/// Exact read without assuming that a source fills a request.
pub fn Input::exact(
  self : Input,
  length : Int32,
  eof_ok~ : Bool = false,
) -> Bytes? raise {
  if length < 0 || length > 16 * 1024 * 1024 {
    fail("limit", "invalid read allocation", offset=self.offset)
  }
  let result = Array::make(length, b'\x00')
  let mut n = 0
  while n < length {
    if self.offset >= self.limit {
      fail("limit", "input byte limit reached", offset=self.offset)
    }
    let wanted = (length - n).min(
      (self.limit - self.offset).min(16777216L).to_int(),
    )
    let chunk = (self.read)(wanted)
    if chunk.length() > wanted {
      fail("io", "source exceeded read request", offset=self.offset)
    }
    if chunk.is_empty() {
      if n == 0 && eof_ok {
        return None
      }
      fail(
        "truncated",
        "unexpected EOF: needed \{length}, received \{n}",
        offset=self.offset,
      )
    }
    for i = 0; i < chunk.length(); i = i + 1 {
      result[n + i] = chunk[i]
    }
    n = n + chunk.length()
    self.offset = self.offset + chunk.length().to_int64()
  }
  Some(Bytes::from_array(result))
}

///|
pub fn Input::required(self : Input, n : Int32) -> Bytes raise {
  match self.exact(n) {
    Some(bytes) => bytes
    None => fail("truncated", "missing required bytes", offset=self.offset)
  }
}

///|
/// Useful for tests and callers who already own a byte buffer; not used by CLI.
pub fn input_from_bytes(
  bytes : Bytes,
  chunk_size~ : Int32 = 4096,
) -> Input raise XptError {
  if chunk_size <= 0 {
    fail("limit", "chunk size must be positive")
  }
  let mut at = 0
  Input::new(fn(n) {
    let end = (at + n.min(chunk_size)).min(bytes.length())
    let out = bytes[at:end].to_owned()
    at = end
    out
  })
}

///|
pub struct Output {
  write : (Bytes) -> Unit raise
  mut offset : Int64
  mut failed : Bool
}

///|
pub fn Output::new(write : (Bytes) -> Unit raise) -> Output {
  { write, offset: 0L, failed: false, }
}

///|
pub fn Output::offset(self : Output) -> Int64 {
  self.offset
}

///|
/// Sink must consume all bytes or raise. After a failure it cannot be reused.
pub fn Output::put(self : Output, bytes : Bytes) -> Unit raise {
  if self.failed {
    fail("state", "output previously failed", offset=self.offset)
  }
  errdefer {
    self.failed = true
  }
  (self.write)(bytes)
  self.offset = self.offset + bytes.length().to_int64()
}
