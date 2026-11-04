///|
extern "C" fn exit_raw(code : Int32) -> Unit = "mx_exit"

///|
pub fn stderr(message : String) -> Unit {
  let bytes = @utf8.encode(message[:])
  ignore(write_raw(2, bytes, bytes.length()))
}

///|
pub fn exit(code : Int32) -> Unit {
  exit_raw(code)
}
