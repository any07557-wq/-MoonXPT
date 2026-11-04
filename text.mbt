///|
let cp1252_high : Array[Int32] = [
  0x20ac, -1, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030, 0x0160,
  0x2039, 0x0152, -1, 0x017d, -1, -1, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013,
  0x2014, 0x02dc, 0x2122, 0x0161, 0x203a, 0x0153, -1, 0x017e, 0x0178,
]

///|
pub fn decode_text(bytes : Bytes, encoding : Encoding) -> String raise XptError {
  let out = StringBuilder()
  for byte in bytes {
    let n = byte.to_int()
    let code = match encoding {
      Ascii => if n > 127 { fail("encoding", "non-ASCII byte") } else { n }
      Windows1252 => if n >= 128 && n < 160 { cp1252_high[n - 128] } else { n }
    }
    if code < 0 {
      fail("encoding", "undefined Windows-1252 byte")
    }
    out.write_char(code.unsafe_to_char())
  }
  out.to_string()
}

///|
pub fn encode_text(text : String, encoding : Encoding) -> Bytes raise XptError {
  let out : Array[Byte] = []
  for c in text {
    let n = c.to_int()
    let mut code = -1
    match encoding {
      Ascii => if n <= 127 { code = n }
      Windows1252 =>
        if n < 128 || (n >= 160 && n <= 255) {
          code = n
        } else {
          for i = 0; i < 32; i = i + 1 {
            if cp1252_high[i] == n {
              code = 128 + i
              break
            }
          }
        }
    }
    if code < 0 {
      fail(
        "encoding",
        "character U+\{n.to_string(radix=16)} is not representable",
      )
    }
    out.push(code.to_byte())
  }
  Bytes::from_array(out)
}

///|
pub fn text_field(bytes : Bytes, encoding : Encoding) -> String raise XptError {
  decode_text(trim_field(bytes), encoding)
}
