///|
test "short reads and exact truncation offsets" {
  let src = @moonxpt.input_from_bytes(b"abcde", chunk_size=1)
  assert_eq(src.required(3), b"abc")
  assert_eq(src.offset(), 3L)
  try src.required(3) catch {
    @moonxpt.XptError(d) => {
      assert_eq(d.kind, "truncated")
      assert_eq(d.offset, Some(5L))
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "explicit early stop makes no further source calls" {
  let mut reads = 0
  let src = @moonxpt.Input::new(n => {
    reads = reads + 1
    Bytes::make(n, b'x')
  })
  ignore(src.required(2))
  assert_eq(reads, 1)
  assert_eq(src.offset(), 2L)
}

///|
test "source errors propagate and sink is poisoned" {
  let src = @moonxpt.Input::new(_ => @moonxpt.fail("io", "mock failure"))
  try src.required(1) catch {
    @moonxpt.XptError(d) => assert_eq(d.kind, "io")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  let out = @moonxpt.Output::new(_ => @moonxpt.fail("io", "mock sink failure"))
  try out.put(b"x") catch {
    _ => ()
  } noraise {
    _ => assert_true(false)
  }
  try out.put(b"x") catch {
    @moonxpt.XptError(d) => assert_eq(d.kind, "state")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
