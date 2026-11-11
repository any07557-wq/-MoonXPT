///|
pub(all) struct Observation {
  index : Int64
  offset : Int64
  raw : Bytes
  values : Array[Value]
} derive(Eq, @debug.Debug)

///|
/// A pull reader keeps at most one row, tail lookahead and a bounded schema probe.
pub struct Reader {
  priv input : Input
  priv options : ReadOptions
  priv library_meta : LibraryMetadata
  priv mut current : DatasetMetadata?
  priv mut next_meta : DatasetMetadata?
  priv mut count : Int32
  priv mut row_index : Int64
  priv mut data_start : Int64
  priv pending : Array[Byte]
  priv mut pending_at : Int32
  priv mut final_rows : Int32?
  priv mut done : Bool
  priv seen : Map[String, Bool]
  priv boundary_options : BoundaryOptions
  priv mut last_boundary : BoundaryReport?
  priv resolved : Map[Int64, BoundaryReport]
  priv header_cache : Map[Int64, (DatasetMetadata, Int64)?]
}

///|
pub fn Reader::new(
  input : Input,
  options~ : ReadOptions = ReadOptions::default(),
  boundary_options~ : BoundaryOptions = BoundaryOptions::default(),
) -> Reader raise {
  ignore(validate_layout([], options.limits))
  if boundary_options.max_boundary_candidates < 1 ||
    boundary_options.max_boundary_candidates > 4096 ||
    boundary_options.max_replay_bytes < 80 ||
    boundary_options.max_replay_bytes > 67108864 ||
    boundary_options.max_search_steps < 1 ||
    boundary_options.max_search_steps > 1000000 {
    v5_fail("limit", "E_V5_RESOURCE_LIMIT", "invalid boundary resource options")
  }
  input.limit = input.limit.min(options.limits.max_input_bytes)
  let hints : Map[String, Int64] = Map([])
  for name, n in options.row_hints {
    let key = name.to_upper()
    if hints.contains(key) ||
      !valid_name(encode_text(name, Ascii)) ||
      n < 0L ||
      n > options.limits.max_rows {
      fail("schema", "invalid or duplicate row hint")
    }
    hints[key] = n
  }
  let options = { ..options, row_hints: hints, }
  let library_meta = read_library(input)
  {
    input,
    options,
    library_meta,
    current: None,
    next_meta: None,
    count: 0,
    row_index: 0L,
    data_start: 0L,
    pending: [],
    pending_at: 0,
    final_rows: None,
    done: true,
    seen: Map([]),
    boundary_options,
    last_boundary: None,
    resolved: Map([]),
    header_cache: Map([]),
  }
}

///|
pub fn Reader::library(self : Reader) -> LibraryMetadata {
  self.library_meta
}

///|
pub fn Reader::next_dataset(self : Reader) -> DatasetMetadata? raise {
  if !self.done {
    fail("state", "consume the current member or stop reading before advancing")
  }
  let candidate = match self.next_meta {
    Some(meta) => {
      self.next_meta = None
      Some(meta)
    }
    None =>
      match self.input.exact(80, eof_ok=true) {
        None => None
        Some(first) =>
          Some(read_dataset(self.input, first, self.options.limits))
      }
  }
  if candidate is Some(meta) {
    if self.count >= self.options.limits.max_datasets {
      fail("limit", "member count exceeds limit", offset=self.input.offset())
    }
    let name = text_field(meta.name, Ascii)
    let key = name.to_upper()
    if self.seen.contains(key) {
      fail("schema", "duplicate dataset name", dataset=name)
    }
    self.seen[key] = true
    if self.options.row_hints.get(key) is Some(n) {
      if n < 0L ||
        n > self.options.limits.max_rows ||
        (meta.row_width == 0 && n != 0L) ||
        (
          meta.row_width > 0 &&
          n > self.options.limits.max_input_bytes / meta.row_width.to_int64()
        ) {
        fail("limit", "invalid row count hint", dataset=name)
      }
    }
    self.count = self.count + 1
    self.current = Some({ ..meta, variables: meta.variables.copy(), })
    self.row_index = 0L
    self.data_start = self.input.offset()
    self.pending.clear()
    self.pending_at = 0
    self.final_rows = None
    self.done = false
    self.last_boundary = None
  }
  if candidate is None {
    for name, _ in self.options.row_hints {
      if !self.seen.contains(name) {
        fail(
          "member",
          "row hint refers to an absent member: \{name}",
          offset=self.input.offset(),
        )
      }
    }
  }
  candidate
}

///|
fn Reader::available(self : Reader) -> Int32 {
  self.pending.length() - self.pending_at
}

///|
fn Reader::append(self : Reader, bytes : Bytes) -> Unit {
  if self.pending_at > 0 {
    let remaining = self.pending[self.pending_at:].to_owned()
    self.pending.clear()
    self.pending.push_iter(remaining.iter())
    self.pending_at = 0
  }
  self.pending.push_iter(bytes.iter())
}

///| A finite tail is compatible with padding p iff 0<=p<80, p is all spaces,

///|
/// and the preceding bytes form complete rows. Never assume blank means EOF.
fn Reader::tail_counts(
  self : Reader,
  width : Int32,
) -> Array[Int32] raise XptError {
  let meta = self.current.unwrap()
  let boundary = self.data_start +
    self.row_index * width.to_int64() +
    self.available().to_int64()
  let suffix = Bytes::from_array(
    self.pending[(self.pending.length() - 79).max(self.pending_at):],
  )
  let report = resolve_v5_boundary(
    meta,
    self.data_start,
    boundary,
    suffix,
    row_policy=self.boundary_options.row_count_policy,
    padding_policy=self.boundary_options.padding_policy,
    limits=self.options.limits,
  ) catch {
    XptError(d) => {
      if d.code() == "E_V5_INVALID_PADDING" {
        return []
      }
      raise XptError(d)
    }
  }
  report.candidate_counts.map(n => (n - self.row_index).to_int())
}

///|
pub fn Reader::boundary_report(self : Reader) -> BoundaryReport? {
  self.last_boundary.map(r => {
    ..r,
    candidate_counts: r.candidate_counts.copy(),
  })
}

///|
fn Reader::finish_tail(
  self : Reader,
  counts : Array[Int32],
  meta : DatasetMetadata,
) -> Unit raise XptError {
  let suffix = Bytes::from_array(
    self.pending[(self.pending.length() - 79).max(self.pending_at):],
  )
  let report = resolve_v5_boundary(
    meta,
    self.data_start,
    self.data_start +
    self.row_index * meta.row_width.to_int64() +
    self.available().to_int64(),
    suffix,
    row_policy=self.boundary_options.row_count_policy,
    padding_policy=self.boundary_options.padding_policy,
    limits=self.options.limits,
  )
  self.last_boundary = Some(report)
  if counts.is_empty() {
    fail(
      "truncated",
      "data tail is neither complete observations nor legal padding",
      offset=self.input.offset(),
      dataset=text_field(meta.name, Ascii),
    )
  }
  if counts.length() > 1 && self.options.tail_policy == Reject {
    v5_fail(
      "ambiguous",
      "E_V5_ROW_COUNT_AMBIGUOUS",
      "V5 has no row count: trailing spaces permit multiple row counts; supply a member row hint or explicit trim policy",
      offset=self.data_start + self.row_index * meta.row_width.to_int64(),
      dataset=text_field(meta.name, Ascii),
      row=self.row_index,
    )
  }
  self.final_rows = Some(counts[counts.length() - 1])
}

///|
fn Reader::emit(
  self : Reader,
  meta : DatasetMetadata,
) -> (Int64, Bytes) raise XptError {
  if self.row_index >= self.options.limits.max_rows {
    fail(
      "limit",
      "row count exceeds limit",
      dataset=text_field(meta.name, Ascii),
      row=self.row_index,
    )
  }
  let raw = Bytes::from_array(
    self.pending[self.pending_at:self.pending_at + meta.row_width],
  )
  let offset = self.data_start + self.row_index * meta.row_width.to_int64()
  self.pending_at = self.pending_at + meta.row_width
  self.row_index = self.row_index + 1L
  (offset, raw)
}

///|
pub fn Reader::next_raw(self : Reader) -> (Int64, Bytes)? raise {
  if self.done {
    return None
  }
  let meta = self.current.unwrap_or_else(() => {
    fail("state", "call next_dataset before reading rows")
  })
  let name = text_field(meta.name, Ascii)
  if self.options.row_hints.get(name.to_upper()) is None &&
    self.boundary_options.row_count_policy == RequireExplicitCount {
    v5_fail(
      "policy",
      "E_V5_ROW_COUNT_REQUIRED",
      "explicit member row count required",
      offset=self.data_start,
      dataset=name,
    )
  }
  let explicit = self.options.row_hints.get(name.to_upper())
  let plan = self.resolved.get(self.data_start)
  if plan is Some(report) {
    self.last_boundary = Some(report)
    if report.row_count is None && self.options.tail_policy == Reject {
      v5_fail(
        "ambiguous",
        "E_V5_ROW_COUNT_AMBIGUOUS",
        "multiple row counts on the unique member chain",
        offset=report.boundary_offset,
        dataset=name,
      )
    }
  }
  let goal = match explicit {
    Some(_) => explicit
    None =>
      match plan {
        Some(report) =>
          Some(
            report.row_count.unwrap_or_else(() => {
              report.candidate_counts[report.candidate_counts.length() - 1]
            }),
          )
        None => None
      }
  }
  if goal is Some(hint) {
    if self.row_index < hint {
      while self.available() < meta.row_width {
        self.append(self.input.required(80))
      }
      return Some(self.emit(meta))
    }
    let expected_padding = ((80L - hint * meta.row_width.to_int64() % 80L) % 80L).to_int()
    if self.available() != expected_padding {
      fail(
        "structure",
        "row hint does not end at legal blank padding",
        offset=self.data_start + hint * meta.row_width.to_int64(),
        dataset=name,
      )
    }
    let checked = resolve_v5_boundary(
      meta,
      self.data_start,
      self.input.offset(),
      Bytes::from_array(self.pending[self.pending_at:]),
      hint~,
      padding_policy=self.boundary_options.padding_policy,
      limits=self.options.limits,
    )
    self.last_boundary = match plan {
      Some(report) => Some(report)
      None => Some(checked)
    }
    match self.input.exact(80, eof_ok=true) {
      None => ()
      Some(first) => {
        let offset = self.input.offset() - 80L
        self.next_meta = Some(
          read_dataset(self.input, first, self.options.limits) catch {
            XptError(d) =>
              v5_fail(
                d.kind,
                "E_V5_INVALID_MEMBER_HEADER",
                d.reason,
                offset~,
                dataset=name,
              )
            e => raise e
          },
        )
      }
    }
    self.done = true
    return None
  }
  while true {
    if self.final_rows is Some(n) {
      if n == 0 {
        self.done = true
        return None
      }
      self.final_rows = Some(n - 1)
      return Some(self.emit(meta))
    }
    // Hold at least the last physical record so ambiguous blank rows are not
    // emitted before EOF or a verified member boundary is available.
    if meta.row_width > 0 && self.available() >= meta.row_width + 80 {
      return Some(self.emit(meta))
    }
    match self.input.exact(80, eof_ok=true) {
      None => self.finish_tail(self.tail_counts(meta.row_width), meta)
      Some(block) =>
        if header_is(block, "MEMBER") {
          if self.probe_member(block) is Some(_) &&
            !self.tail_counts(meta.row_width).is_empty() {
            self.resolve_chain(block)
            return self.next_raw()
          }
          self.append(block)
        } else {
          self.append(block)
        }
    }
    continue
  } nobreak {
    None
  }
}

///|
pub fn decode_observation(
  meta : DatasetMetadata,
  raw : Bytes,
  index : Int64,
  offset : Int64,
) -> Observation raise {
  if raw.length() != meta.row_width {
    fail("schema", "row byte width mismatch", offset~, row=index)
  }
  let values : Array[Value] = []
  for v in meta.variables {
    let data = field(raw, v.position, v.width)
    values.push(
      match v.kind {
        Text => Character(data)
        Number =>
          Numeric(
            at_context(
              offset + v.position.to_int64(),
              () => decode_numeric(data),
              dataset=text_field(meta.name, Ascii),
              variable=text_field(v.name, Ascii),
              row=index,
            ),
          )
      },
    )
  }
  { index, offset, raw, values, }
}

///|
pub fn Reader::next_row(self : Reader) -> Observation? raise {
  let index = self.row_index
  match self.next_raw() {
    None => None
    Some((offset, raw)) =>
      Some(decode_observation(self.current.unwrap(), raw, index, offset))
  }
}
