///|
#borrow(path)
extern "C" fn open_read_raw(path : Bytes) -> Int32 = "mx_open_read"

///|
#borrow(buffer)
extern "C" fn read_raw(
  fd : Int32,
  buffer : FixedArray[Byte],
  n : Int32,
) -> Int32 = "mx_read"

///|
extern "C" fn close_raw(fd : Int32) -> Int32 = "mx_close"

///|
extern "C" fn tell_raw(fd : Int32) -> Int64 = "mx_tell"

///|
extern "C" fn seek_raw(fd : Int32, offset : Int64) -> Int32 = "mx_seek"

///|
pub struct File {
  priv fd : Int32
  priv mut closed : Bool
}

///|
fn path_bytes(path : String) -> Bytes raise @xpt.XptError {
  if path.contains_char('\u0000') {
    @xpt.fail("io", "path contains NUL")
  }
  @utf8.encode(path[:]) + b"\x00"
}

///|
pub fn File::open(path : String) -> File raise @xpt.XptError {
  let fd = open_read_raw(path_bytes(path))
  if fd < 0 {
    @xpt.fail("io", "cannot open \{path}: errno \{-fd}")
  }
  { fd, closed: false, }
}

///|
pub fn File::read(self : File, n : Int32) -> Bytes raise @xpt.XptError {
  if self.closed {
    @xpt.fail("io", "read from closed file")
  }
  if n < 0 || n > 16777216 {
    @xpt.fail("limit", "invalid platform read allocation")
  }
  let buffer = FixedArray::make(n, b'\x00')
  let count = read_raw(self.fd, buffer, n)
  if count < 0 {
    @xpt.fail("io", "read failed: errno \{-count}")
  }
  Bytes::from_array(buffer[:count])
}

///|
pub fn File::input(
  self : File,
  max_bytes~ : Int64 = 1099511627776L,
) -> @xpt.Input raise @xpt.XptError {
  let origin = tell_raw(self.fd)
  @xpt.Input::new(
    n => self.read(n),
    max_bytes~,
    reposition=if origin >= 0L {
      Some(offset => {
        if self.closed {
          @xpt.fail("io", "seek on closed file")
        }
        if offset < 0L || offset > 9223372036854775807L - origin {
          @xpt.fail("io", "stream-relative seek overflow", offset~)
        }
        let status = seek_raw(self.fd, origin + offset)
        if status < 0 {
          @xpt.fail("io", "seek failed: errno \{-status}", offset~)
        }
      })
    } else {
      None
    },
  )
}

///|
pub fn File::close(self : File) -> Unit raise @xpt.XptError {
  if !self.closed {
    self.closed = true
    let status = close_raw(self.fd)
    if status < 0 {
      @xpt.fail("io", "close failed: errno \{-status}")
    }
  }
}

///|
pub fn File::cleanup(self : File) -> Unit {
  self.close() catch {
    _ => ()
  }
}
