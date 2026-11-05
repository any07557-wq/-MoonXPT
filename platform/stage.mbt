///|
#borrow(path)
extern "C" fn temp_raw(path : FixedArray[Byte]) -> Int32 = "mx_temp"

///|
#borrow(path)
extern "C" fn exists_raw(path : Bytes) -> Int32 = "mx_exists"

///|
#borrow(a, b)
extern "C" fn rename_raw(a : Bytes, b : Bytes) -> Int32 = "mx_rename"

///|
#borrow(a, b)
extern "C" fn link_raw(a : Bytes, b : Bytes) -> Int32 = "mx_link"

///|
#borrow(path)
extern "C" fn remove_raw(path : Bytes) -> Int32 = "mx_remove"

///|
#borrow(a, b)
extern "C" fn same_raw(a : Bytes, b : Bytes) -> Int32 = "mx_same"

///|
#borrow(path, owned)
extern "C" fn remove_same_raw(path : Bytes, owned : Bytes) -> Int32 = "mx_remove_same"

///|
pub fn ensure_distinct(a : String, b : String) -> Unit raise @xpt.XptError {
  let same = same_raw(path_bytes(a), path_bytes(b))
  if same < 0 {
    @xpt.fail("io", "cannot resolve output paths: errno \{-same}")
  }
  if same == 1 {
    @xpt.fail("usage", "input/output or paired outputs refer to the same file")
  }
}

///|
fn create_temp(path : String) -> (File, String) raise {
  let bytes = path_bytes(path + ".moonxpt-XXXXXX")
  let buffer = FixedArray::makei(bytes.length(), i => bytes[i])
  let fd = temp_raw(buffer)
  if fd < 0 {
    @xpt.fail("io", "cannot stage output beside \{path}: errno \{-fd}")
  }
  let file = File::{ fd, closed: false, }
  errdefer file.cleanup()
  let name = @utf8.decode(Bytes::from_array(buffer[:buffer.length() - 1])[:])
  (file, name)
}

///|
pub struct Stage {
  priv file : File
  priv path : String
  priv temporary : String
  priv force : Bool
  priv mut backup : String?
  priv mut published : Bool
  priv mut completed : Bool
}

///|
pub fn Stage::new(path : String, force~ : Bool = false) -> Stage raise {
  let exists = exists_raw(path_bytes(path))
  if exists < 0 {
    @xpt.fail("io", "cannot inspect target \{path}: errno \{-exists}")
  }
  if exists == 1 && !force {
    @xpt.fail("io", "output exists (use --force): \{path}")
  }
  let (file, temporary) = create_temp(path)
  {
    file,
    path,
    temporary,
    force,
    backup: None,
    published: false,
    completed: false,
  }
}

///|
pub fn Stage::output(self : Stage) -> @xpt.Output {
  self.file.output()
}

///|
pub fn Stage::write(self : Stage, bytes : Bytes) -> Unit raise {
  self.file.write(bytes)
}

///|
pub fn Stage::cleanup(self : Stage) -> Unit {
  self.file.cleanup()
  ignore(remove_raw(@utf8.encode((self.temporary + "\u0000")[:])))
  // A backup is deliberately retained if rollback could not safely restore it.
}

///|
fn Stage::backup_target(self : Stage) -> Unit raise {
  if !self.force {
    return
  }
  let exists = exists_raw(path_bytes(self.path))
  if exists < 0 {
    @xpt.fail("io", "cannot inspect replacement target")
  }
  if exists == 1 {
    let (file, path) = create_temp(self.path + ".backup")
    file.close()
    let status = rename_raw(path_bytes(self.path), path_bytes(path))
    if status < 0 {
      ignore(remove_raw(path_bytes(path)))
      @xpt.fail("io", "cannot back up target: errno \{-status}")
    }
    self.backup = Some(path)
  }
}

///|
fn Stage::rollback(self : Stage) -> Unit raise {
  if self.published {
    let status = remove_same_raw(
      path_bytes(self.path),
      path_bytes(self.temporary),
    )
    if status < 0 {
      @xpt.fail(
        "io",
        "rollback refused to remove changed output; backup retained at \{self.backup.unwrap_or("none")}",
      )
    }
    self.published = false
  }
  if self.backup is Some(backup) {
    if link_raw(path_bytes(backup), path_bytes(self.path)) < 0 {
      @xpt.fail(
        "io",
        "rollback needs manual restore: \{backup} -> \{self.path}",
      )
    }
    ignore(remove_raw(path_bytes(backup)))
    self.backup = None
  }
}

///| Each target promotion is atomic; process failures roll the pair back.

///|
/// A machine crash between promotions is not a cross-file atomic transaction.
// This synchronous transaction must preserve the publication error while also
// reporting a failed rollback; cleanup may replace that error with recovery paths.
#warnings("-fragile_catch_all")
pub fn commit_group(stages : Array[Stage]) -> Unit raise {
  for stage in stages {
    if stage.completed {
      @xpt.fail("state", "output stage was already committed")
    }
  }
  for stage in stages {
    stage.file.sync()
    stage.file.close()
  }
  try {
    for stage in stages {
      stage.backup_target()
    }
    for stage in stages {
      let status = link_raw(path_bytes(stage.temporary), path_bytes(stage.path))
      if status < 0 {
        @xpt.fail("io", "cannot publish \{stage.path}: errno \{-status}")
      }
      stage.published = true
    }
  } catch {
    original => {
      let original_reason = match original {
        @xpt.XptError(d) => d.reason
        _ => "publication failed"
      }
      let errors : Array[String] = []
      for i = stages.length() - 1; i >= 0; i = i - 1 {
        stages[i].rollback() catch {
          @xpt.XptError(d) => errors.push(d.reason)
          _ => errors.push("rollback failed; retain backup for recovery")
        }
      }
      if !errors.is_empty() {
        @xpt.fail("io", original_reason + "; " + errors.join("; "))
      }
      raise original
    }
  }
  for stage in stages {
    stage.completed = true
    if stage.backup is Some(backup) {
      let status = remove_raw(path_bytes(backup))
      if status < 0 {
        @xpt.fail(
          "io",
          "output complete; cannot remove recovery backup \{backup}",
        )
      }
      stage.backup = None
    }
    ignore(remove_raw(path_bytes(stage.temporary)))
  }
}

///|
pub fn Stage::write_text(self : Stage, text : String) -> Unit raise {
  self.write(@utf8.encode(text[:]))
}
