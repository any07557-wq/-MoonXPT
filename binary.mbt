///|
/// Bounds checked byte slicing, shared by the metadata and row engines.
pub fn field(
  bytes : Bytes,
  start : Int32,
  length : Int32,
) -> Bytes raise XptError {
  if start < 0 ||
    length < 0 ||
    start > bytes.length() ||
    length > bytes.length() - start {
    fail("bounds", "field exceeds buffer")
  }
  bytes[start:start + length].to_owned()
}

///|
pub fn u16be(bytes : Bytes, at : Int32) -> Int32 raise XptError {
  let b = field(bytes, at, 2)
  b[0].to_int() * 256 + b[1].to_int()
}

///|
pub fn u32be(bytes : Bytes, at : Int32) -> Int64 raise XptError {
  let b = field(bytes, at, 4)
  let mut n = 0L
  for x in b {
    n = n * 256L + x.to_int().to_int64()
  }
  n
}

///|
pub fn padding(length : Int32) -> Int32 raise XptError {
  if length < 0 {
    fail("bounds", "negative alignment length")
  }
  (80 - length % 80) % 80
}

///|
pub fn is_spaces(bytes : Bytes) -> Bool {
  bytes.iter().all(x => x == b' ')
}

///|
pub fn trim_field(bytes : Bytes) -> Bytes {
  let mut n = bytes.length()
  while n > 0 && bytes[n - 1] == b' ' {
    n = n - 1
  }
  bytes[:n].to_owned()
}

///|
pub fn decimal_field(
  bytes : Bytes,
  at : Int32,
  length : Int32,
) -> Int32 raise XptError {
  let b = field(bytes, at, length)
  let mut value = 0
  let mut seen = false
  for x in b {
    if x >= b'0' && x <= b'9' {
      if value > (2147483647 - (x.to_int() - 48)) / 10 {
        fail("limit", "decimal field overflow")
      }
      value = value * 10 + x.to_int() - 48
      seen = true
    } else if x != b' ' {
      fail("structure", "non-decimal header attribute")
    }
  }
  if !seen {
    fail("structure", "empty decimal header attribute")
  }
  value
}

///|
/// Mutable builder has explicit capacity bounds, never unchecked byte writes.
pub struct ByteBuilder {
  data : Array[Byte]
}

///|
pub fn ByteBuilder::new(
  length : Int32,
  fill~ : Byte = b' ',
) -> ByteBuilder raise XptError {
  if length < 0 || length > 16777216 {
    fail("limit", "builder exceeds allocation limit")
  }
  { data: Array::make(length, fill), }
}

///|
pub fn ByteBuilder::put(
  self : ByteBuilder,
  at : Int32,
  bytes : Bytes,
) -> Unit raise XptError {
  if at < 0 ||
    at > self.data.length() ||
    bytes.length() > self.data.length() - at {
    fail("bounds", "builder write exceeds capacity")
  }
  for i = 0; i < bytes.length(); i = i + 1 {
    self.data[at + i] = bytes[i]
  }
}

///|
pub fn ByteBuilder::u16(
  self : ByteBuilder,
  at : Int32,
  n : Int32,
) -> Unit raise XptError {
  if n < 0 || n > 65535 {
    fail("bounds", "integer exceeds unsigned 16-bit range")
  }
  self.put(at, Bytes::from_array([(n / 256).to_byte(), n.to_byte()]))
}

///|
pub fn ByteBuilder::u32(
  self : ByteBuilder,
  at : Int32,
  n : Int64,
) -> Unit raise XptError {
  if n < 0L || n > 4294967295L {
    fail("bounds", "integer exceeds unsigned 32-bit range")
  }
  self.put(
    at,
    Bytes::from_array([
      (n >> 24).to_byte(),
      (n >> 16).to_byte(),
      (n >> 8).to_byte(),
      n.to_byte(),
    ]),
  )
}

///|
pub fn ByteBuilder::bytes(self : ByteBuilder) -> Bytes {
  Bytes::from_array(self.data)
}

///|
pub fn header(kind : String) -> Bytes raise XptError {
  if kind.length() > 8 {
    fail("structure", "header name too long")
  }
  @utf8.encode(
    ("HEADER RECORD*******" +
    kind.pad_end(8, ' ') +
    "HEADER RECORD!!!!!!!000000000000000000000000000000  ")[:],
  )
}

///|
pub fn header_is(bytes : Bytes, kind : String) -> Bool {
  if bytes.length() != 80 {
    return false
  }
  let prefix = @utf8.encode(
    ("HEADER RECORD*******" + kind.pad_end(8, ' ') + "HEADER RECORD!!!!!!!")[:],
  )
  bytes.has_prefix(prefix[:])
}

///|
pub fn expect_header(
  bytes : Bytes,
  kind : String,
  offset : Int64,
) -> Unit raise XptError {
  if !header_is(bytes, kind) {
    fail("structure", "expected \{kind} header", offset~)
  }
  for i = 48; i < 78; i = i + 1 {
    if bytes[i] < b'0' || bytes[i] > b'9' {
      fail(
        "structure",
        "non-decimal header payload",
        offset=offset + i.to_int64(),
      )
    }
    let used = (
        kind == "MEMBER" && ((i >= 65 && i <= 67) || (i >= 74 && i <= 77))
      ) ||
      (kind == "NAMESTR" && i >= 54 && i <= 57)
    if !used && bytes[i] != b'0' {
      fail(
        "structure",
        "nonzero reserved V5 header attribute",
        offset=offset + i.to_int64(),
      )
    }
  }
  if bytes[78] != b' ' || bytes[79] != b' ' {
    fail("structure", "invalid header padding", offset=offset + 78L)
  }
}
