///|
/// Only schema JSON is loaded in full; it is bounded independently of data size.
pub fn read_text(path : String, max_bytes~ : Int32 = 16777216) -> String raise {
  if max_bytes < 0 || max_bytes > 16777216 {
    @xpt.fail("limit", "invalid text read limit")
  }
  let file = File::open(path)
  defer file.cleanup()
  let data : Array[Byte] = []
  while true {
    let chunk = file.read((max_bytes - data.length() + 1).min(4096))
    if chunk.is_empty() {
      break
    }
    if chunk.length() > max_bytes - data.length() {
      @xpt.fail("limit", "metadata JSON exceeds byte limit")
    }
    data.push_iter(chunk.iter())
  }
  @utf8.decode(Bytes::from_array(data)[:], ignore_bom=false) catch {
    _ => @xpt.fail("encoding", "metadata JSON is not valid UTF-8")
  }
}
