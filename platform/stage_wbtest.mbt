///|
fn stage_test_paths() -> (String, String) raise {
  let (file, path) = create_temp("/tmp/moonxpt-test")
  file.close()
  ignore(remove_raw(path_bytes(path)))
  (path + ".one", path + ".two")
}

///|
test "publication race rolls back the first output and preserves competing file" {
  let (a, b) = stage_test_paths()
  defer {
    ignore(remove_raw(@utf8.encode((a + "\u0000")[:])))
    ignore(remove_raw(@utf8.encode((b + "\u0000")[:])))
  }
  let one = Stage::new(a)
  defer one.cleanup()
  let two = Stage::new(b)
  defer two.cleanup()
  one.write(b"first")
  two.write(b"second")
  let competitor = File::create(b)
  competitor.write(b"external")
  competitor.close()
  try commit_group([one, two]) catch {
    @xpt.XptError(d) => assert_eq(d.kind, "io")
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  assert_eq(exists_raw(path_bytes(a)), 0)
  assert_eq(read_text(b), "external")
}

///|
test "replacement backup is restored when another target races publication" {
  let (a, b) = stage_test_paths()
  defer {
    ignore(remove_raw(@utf8.encode((a + "\u0000")[:])))
    ignore(remove_raw(@utf8.encode((b + "\u0000")[:])))
  }
  let old = File::create(a)
  old.write(b"original")
  old.close()
  let one = Stage::new(a, force=true)
  defer one.cleanup()
  let two = Stage::new(b)
  defer two.cleanup()
  one.write(b"replacement")
  two.write(b"second")
  let competitor = File::create(b)
  competitor.write(b"external")
  competitor.close()
  try commit_group([one, two]) catch {
    _ => ()
  } noraise {
    _ => assert_true(false)
  }
  assert_eq(read_text(a), "original")
  assert_eq(read_text(b), "external")
}
