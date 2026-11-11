///|
/// A node caches only a validated schema and the preceding <=79 bytes.
priv struct ChainNode {
  header_offset : Int64
  observation_start : Int64
  meta : DatasetMetadata?
  tail : Bytes
}

///|
priv struct ChainEdge {
  target : Int32
  report : BoundaryReport
}

///|
fn chain_walk(
  nodes : Array[ChainNode],
  edges : Array[Array[ChainEdge]],
  at : Int32,
  path : Array[ChainEdge],
  seen : Map[String, Bool],
  hints : Map[String, Int64],
  paths : Array[Array[ChainEdge]],
  budget : Array[Int32],
  member_count : Int32,
  max_members : Int32,
) -> Unit raise XptError {
  if paths.length() >= 2 {
    return
  }
  budget[0] = budget[0] - 1
  if budget[0] < 0 {
    v5_fail(
      "limit", "E_V5_RESOURCE_LIMIT", "member-chain search budget exhausted",
    )
  }
  for edge in edges[at] {
    if nodes[edge.target].meta is Some(meta) {
      let key = text_field(meta.name, Ascii).to_upper()
      if seen.contains(key) {
        continue
      }
      if member_count >= max_members {
        v5_fail(
          "limit",
          "E_V5_RESOURCE_LIMIT",
          "member-chain member limit exceeded",
          offset=nodes[edge.target].header_offset,
        )
      }
      seen[key] = true
      path.push(edge)
      chain_walk(
        nodes,
        edges,
        edge.target,
        path,
        seen,
        hints,
        paths,
        budget,
        member_count + 1,
        max_members,
      )
      ignore(path.pop())
      ignore(seen.remove(key))
    } else {
      let mut complete = true
      for key, _ in hints {
        if !seen.contains(key) {
          complete = false
        }
      }
      if complete {
        let complete_path = path.copy()
        complete_path.push(edge)
        paths.push(complete_path)
      }
    }
    if paths.length() >= 2 {
      return
    }
  }
}

///|
/// A header probe never chooses a boundary. Failed structure is replayed as data.
fn Reader::probe_member(
  self : Reader,
  block : Bytes,
) -> (DatasetMetadata, Int64)? raise {
  let offset = self.input.offset() - 80L
  if self.header_cache.get(offset) is Some(result) {
    return result
  }
  if self.header_cache.length() >= self.boundary_options.max_boundary_candidates {
    v5_fail(
      "limit",
      "E_V5_RESOURCE_LIMIT",
      "header probe candidate limit exceeded",
      offset~,
    )
  }
  self.input.start_capture()
  let candidate = try {
    let meta = read_dataset(self.input, block, self.options.limits)
    Some((meta, self.input.offset()))
  } catch {
    XptError(d) => {
      if d.kind == "limit" {
        self.input.rollback_capture()
        v5_fail(
          "limit",
          "E_V5_RESOURCE_LIMIT",
          "member header exceeds descriptor limits",
          offset?=d.offset,
        )
      }
      None
    }
    e => {
      self.input.rollback_capture()
      raise e
    }
  }
  self.input.rollback_capture()
  self.header_cache[offset] = candidate
  candidate
}

///| Preflight only after a real structural fork, preserving ordinary streaming.

///| Seekable input is rescanned without observation storage. Nonseekable input

///|
/// needs a bounded replay suffix; it fails explicitly before exceeding its cap.
fn Reader::resolve_chain(self : Reader, first : Bytes) -> Unit raise {
  let fork = self.input.offset() - 80L
  let current = self.current.unwrap()
  let nodes : Array[ChainNode] = [
    {
      header_offset: self.data_start,
      observation_start: self.data_start,
      meta: Some(current),
      tail: b"",
    },
  ]
  let replay : Array[Byte] = []
  let mut block = Some(first)
  let mut tail = Bytes::from_array(
    self.pending[(self.pending.length() - 79).max(self.pending_at):],
  )
  let mut header_bytes = 0L
  while block is Some(bytes) {
    let offset = self.input.offset() - 80L
    if self.input.reposition is None {
      if replay.length() > self.boundary_options.max_replay_bytes - 80 {
        v5_fail(
          "limit",
          "E_V5_RESOURCE_LIMIT",
          "nonseekable member fork replay limit exceeded",
          offset~,
        )
      }
      replay.push_iter(bytes.iter())
    }
    if header_is(bytes, "MEMBER") {
      if self.probe_member(bytes) is Some((meta, start)) {
        if nodes.length() - 1 >= self.boundary_options.max_boundary_candidates {
          v5_fail(
            "limit",
            "E_V5_RESOURCE_LIMIT",
            "member candidate limit exceeded",
            offset~,
          )
        }
        header_bytes = header_bytes + (start - offset)
        if header_bytes > self.boundary_options.max_replay_bytes.to_int64() {
          v5_fail(
            "limit",
            "E_V5_RESOURCE_LIMIT",
            "cached member schemas exceed header byte budget",
            offset~,
          )
        }
        nodes.push({
          header_offset: offset,
          observation_start: start,
          meta: Some(meta),
          tail,
        })
      }
    }
    tail = bytes[1:].to_owned()
    block = self.input.exact(80, eof_ok=true)
  }
  let eof = self.input.offset()
  nodes.push({ header_offset: eof, observation_start: eof, meta: None, tail, })
  let edges : Array[Array[ChainEdge]] = Array::makei(nodes.length(), _ => [])
  let budget = [self.boundary_options.max_search_steps]
  for i = 0; i < nodes.length() - 1; i = i + 1 {
    let node = nodes[i]
    let meta = node.meta.unwrap()
    for j = i + 1; j < nodes.length(); j = j + 1 {
      if nodes[j].header_offset < node.observation_start {
        continue
      }
      budget[0] = budget[0] - 1
      if budget[0] < 0 {
        v5_fail("limit", "E_V5_RESOURCE_LIMIT", "member edge budget exhausted")
      }
      let report = Some(
        resolve_v5_boundary(
          meta,
          node.observation_start,
          nodes[j].header_offset,
          nodes[j].tail,
          hint?=self.options.row_hints.get(
            text_field(meta.name, Ascii).to_upper(),
          ),
          row_policy=self.boundary_options.row_count_policy,
          padding_policy=self.boundary_options.padding_policy,
          limits=self.options.limits,
        ),
      ) catch {
        XptError(d) => {
          if d.code() == "E_V5_RESOURCE_LIMIT" {
            raise XptError(d)
          }
          None
        }
      }
      if report is Some(report) {
        edges[i].push({ target: j, report, })
      }
    }
  }
  let paths : Array[Array[ChainEdge]] = []
  let seen : Map[String, Bool] = Map([])
  for key, value in self.seen {
    seen[key] = value
  }
  chain_walk(
    nodes,
    edges,
    0,
    [],
    seen,
    self.options.row_hints,
    paths,
    budget,
    self.count,
    self.options.limits.max_datasets,
  )
  if paths.is_empty() {
    v5_fail(
      "structure",
      "E_V5_TRAILING_GARBAGE",
      "no complete legal member chain to EOF",
      offset=eof,
      dataset=text_field(current.name, Ascii),
    )
  }
  if paths.length() > 1 && self.options.tail_policy == Reject {
    self.last_boundary = Some({
      row_count: None,
      row_count_status: "ambiguous",
      boundary_status: "ambiguous",
      candidate_counts: [],
      padding_bytes: None,
      padding_kind: "undetermined",
      alignment_ok: true,
      observation_start: self.data_start,
      boundary_offset: fork,
      code: Some("E_V5_MEMBER_BOUNDARY_AMBIGUOUS"),
    })
    v5_fail(
      "ambiguous",
      "E_V5_MEMBER_BOUNDARY_AMBIGUOUS",
      "multiple complete legal member chains to EOF",
      offset=fork,
      dataset=text_field(current.name, Ascii),
    )
  }
  let mut node = 0
  for edge in paths[0] {
    self.resolved[nodes[node].observation_start] = if node == 0 &&
      paths.length() > 1 {
      {
        ..edge.report,
        boundary_status: "ambiguous",
        code: Some("E_V5_MEMBER_BOUNDARY_AMBIGUOUS"),
      }
    } else {
      edge.report
    }
    node = edge.target
  }
  if self.input.reposition is Some(seek) {
    seek(fork)
    self.input.replay = b""
  } else {
    self.input.replay = Bytes::from_array(replay)
  }
  self.input.replay_at = 0
  self.input.capture = None
  self.input.offset = fork
}
