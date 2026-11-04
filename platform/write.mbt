///|
#borrow(path)
extern "C" fn create_raw(path : Bytes) -> Int32 = "mx_create"

///|
#borrow(bytes)
extern "C" fn write_raw(fd : Int32, bytes : Bytes, n : Int32) -> Int32 = "mx_write"

///|
extern "C" fn sync_raw(fd : Int32) -> Int32 = "mx_sync"

///|
pub fn File::create(path : String) -> File raise @xpt.XptError {
  let fd = create_raw(path_bytes(path))
  if fd < 0 {
    @xpt.fail("io", "cannot exclusively create \{path}: errno \{-fd}")
  }
  { fd, closed: false, }
}

///|
pub fn File::write(self : File, bytes : Bytes) -> Unit raise @xpt.XptError {
  if self.closed {
    @xpt.fail("io", "write to closed file")
  }
  let status = write_raw(self.fd, bytes, bytes.length())
  if status < 0 {
    @xpt.fail("io", "write failed: errno \{-status}")
  }
}

///|
pub fn File::output(self : File) -> @xpt.Output {
  @xpt.Output::new(b => self.write(b))
}

///|
pub fn File::sync(self : File) -> Unit raise @xpt.XptError {
  if self.closed {
    @xpt.fail("io", "sync on closed file")
  }
  let status = sync_raw(self.fd)
  if status < 0 {
    @xpt.fail("io", "flush failed: errno \{-status}")
  }
}
