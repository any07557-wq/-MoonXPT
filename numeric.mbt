///|
/// Every SAS numeric missing marker is distinct from finite numbers.
pub fn valid_missing(tag : Byte) -> Bool {
  tag == b'.' || tag == b'_' || (tag >= b'A' && tag <= b'Z')
}

///|
/// IBM hexadecimal fraction * 16^(exponent-64); short fields are zero extended.
pub fn decode_numeric(raw : Bytes) -> NumericValue raise XptError {
  if raw.length() < 2 || raw.length() > 8 {
    fail("numeric", "numeric storage width must be 2..8")
  }
  let mut fraction = 0UL
  for i = 1; i < 8; i = i + 1 {
    fraction = (fraction << 8) |
      (if i < raw.length() { raw[i].to_int().to_uint64() } else { 0UL })
  }
  if fraction == 0UL {
    if valid_missing(raw[0]) {
      return Missing(raw[0])
    }
    if raw[0] == b'\x00' {
      return Finite(0.0)
    }
    if raw[0] == b'\x80' {
      return Finite(-0.0)
    }
    fail(
      "numeric", "zero fraction with nonzero exponent is neither zero nor missing",
    )
  }
  if fraction < 0x0010000000000000UL {
    fail("numeric", "non-normalized IBM fraction is not a supported V5 number")
  }
  let exponent = (raw[0].to_int() & 127) - 64
  // Truncate toward zero like SAS/ReadStat so the largest HFP cannot round
  // up to the unrepresentable IEEE value 2^252. Raw bytes retain all bits.
  let shift = (64 - fraction.clz() - 53).max(0)
  let value = (fraction >> shift).to_double() *
    @math.pow(2.0, (4 * exponent - 56 + shift).to_double())
  Finite(if (raw[0].to_int() & 128) != 0 { -value } else { value })
}

///|
/// Full IEEE finite precision fits the IBM fraction. SAS short storage truncates.
pub fn encode_numeric(
  value : NumericValue,
  width : Int32,
) -> Bytes raise XptError {
  if width < 2 || width > 8 {
    fail("numeric", "numeric storage width must be 2..8")
  }
  let b = ByteBuilder::new(8, fill=b'\x00')
  match value {
    Missing(tag) => {
      if !valid_missing(tag) {
        fail("numeric", "unknown SAS missing tag")
      }
      b.put(0, Bytes::from_array([tag]))
    }
    Finite(x) => {
      if x.is_nan() || x.is_inf() {
        fail("numeric", "NaN/infinity is not an explicit missing value")
      }
      if x != 0.0 {
        let mut y = x.abs()
        let mut exponent = 64
        while y >= 1.0 && exponent <= 127 {
          y = y / 16.0
          exponent = exponent + 1
        }
        while y < 0.0625 && exponent >= 0 {
          y = y * 16.0
          exponent = exponent - 1
        }
        if exponent < 0 || exponent > 127 {
          fail("numeric", "value outside IBM hexadecimal floating range")
        }
        let mantissa = (y * 72057594037927936.0).to_uint64()
        b.put(
          0,
          Bytes::from_array([
            (exponent + (if x < 0.0 { 128 } else { 0 })).to_byte(),
          ]),
        )
        let bytes = mantissa.to_be_bytes()
        b.put(1, bytes[1:8].to_owned())
      }
    }
  }
  field(b.bytes(), 0, width)
}

///|
pub fn missing_token(tag : Byte) -> String raise XptError {
  if !valid_missing(tag) {
    fail("numeric", "invalid missing tag")
  }
  if tag == b'.' {
    "."
  } else {
    "." + tag.to_int().unsafe_to_char().to_string()
  }
}
