///|
/// Error context is shared by dataset and observation traversal.
fn Reader::record_failure(
  self : Reader,
  original : Diagnostic,
) -> Diagnostic raise XptError {
  let meta = self.current
  let hint = match meta {
    Some(m) => self.options.row_hints.get(text_field(m.name, Ascii).to_upper())
    None => None
  }
  let expected = match (meta, hint) {
    (Some(m), Some(n)) => Some(n * m.row_width.to_int64())
    _ => None
  }
  let code = if original.code() == "E_TRUNCATED" {
    if self.phase == "member_header" {
      "E_V5_INVALID_MEMBER_HEADER"
    } else if expected is Some(n) && self.input.offset() >= self.data_start + n {
      "E_V5_TRUNCATED_PADDING"
    } else {
      "E_V5_TRUNCATED_OBSERVATION"
    }
  } else if original.kind == "limit" {
    "E_V5_RESOURCE_LIMIT"
  } else {
    original.code()
  }
  let d = if code == original.code() {
    original
  } else {
    { ..original, reason: code + ": " + original.reason, }
  }

  self.failed = true
  if d.kind != "ambiguous" || self.last_boundary is None {
    self.last_boundary = Some({
      row_count: None,
      row_count_status: "invalid",
      boundary_status: "invalid",
      candidate_counts: [],
      padding_bytes: None,
      padding_kind: if self.boundary_options.padding_policy == StrictSpec {
        "ascii_space"
      } else {
        "space_or_nul_compatibility"
      },
      alignment_ok: self.input.offset() % 80L == 0L,
      observation_start: self.data_start,
      boundary_offset: d.offset.unwrap_or(self.input.offset()),
      code: Some(d.code()),
      hint,
      expected_bytes: expected,
      actual_bytes: self.input.offset() - self.data_start,
      policy: if self.boundary_options.row_count_policy == StrictAuto {
        "strict_auto"
      } else {
        "require_explicit_count"
      },
    })
  }

  d
}

///|
pub fn Reader::next_dataset(self : Reader) -> DatasetMetadata? raise {
  if self.failed {
    fail("state", "reader previously failed", offset=self.input.offset())
  }
  self.phase = "member_header"
  self.pull_dataset() catch {
    XptError(d) => raise XptError(self.record_failure(d))
    e => {
      self.failed = true
      raise e
    }
  }
}

///|
/// A failed stream is poisoned; ambiguous/error tails cannot be resumed.
pub fn Reader::next_raw(self : Reader) -> (Int64, Bytes)? raise {
  if self.failed {
    fail("state", "reader previously failed", offset=self.input.offset())
  }
  self.pull_raw() catch {
    XptError(d) => raise XptError(self.record_failure(d))
    e => {
      self.failed = true
      raise e
    }
  }
}
