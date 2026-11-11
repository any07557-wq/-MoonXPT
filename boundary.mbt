///|
/// Policies are separate from the v0.1.0 option records for source compatibility.
pub(all) enum RowCountPolicy {
  StrictAuto
  RequireExplicitCount
} derive(Eq, @debug.Debug)

///|
pub(all) enum PaddingPolicy {
  StrictSpec
  CompatibilityNulPadding
} derive(Eq, @debug.Debug)

///|
pub(all) struct BoundaryOptions {
  row_count_policy : RowCountPolicy
  padding_policy : PaddingPolicy
  max_boundary_candidates : Int32
  max_replay_bytes : Int32
  max_search_steps : Int32
} derive(Eq, @debug.Debug)

///|
pub fn BoundaryOptions::default() -> BoundaryOptions {
  {
    row_count_policy: StrictAuto,
    padding_policy: StrictSpec,
    max_boundary_candidates: 64,
    max_replay_bytes: 16777216,
    max_search_steps: 16384,
  }
}

///|
pub(all) struct BoundaryReport {
  row_count : Int64?
  row_count_status : String
  boundary_status : String
  candidate_counts : Array[Int64]
  padding_bytes : Int32?
  padding_kind : String
  alignment_ok : Bool
  observation_start : Int64
  boundary_offset : Int64
  code : String?
} derive(Eq, @debug.Debug)

///|
/// Preserve Diagnostic's existing public fields and legacy kind values.
pub fn Diagnostic::code(self : Diagnostic) -> String {
  if self.reason.split_once(":") is Some((code, _)) {
    let code = code.to_owned()
    if code.length() >= 5 && code[:5] == "E_V5_" {
      return code
    }
  }
  "E_" + self.kind.to_upper()
}

///|
fn[T] v5_fail(
  kind : String,
  code : String,
  message : String,
  offset? : Int64,
  dataset? : String,
  row? : Int64,
) -> T raise XptError {
  fail(kind, code + ": " + message, offset?, dataset?, row?)
}

///| The caller supplies a TRUSTED physical boundary and its last <=79 bytes.

///|
/// No observation bytes are cached, and arithmetic is checked before multiplying.
pub fn resolve_v5_boundary(
  meta : DatasetMetadata,
  observation_start : Int64,
  boundary : Int64,
  tail : Bytes,
  hint? : Int64,
  row_policy~ : RowCountPolicy = StrictAuto,
  padding_policy~ : PaddingPolicy = StrictSpec,
  limits~ : Limits = Limits::default(),
) -> BoundaryReport raise XptError {
  let name = text_field(meta.name, Ascii)
  let width = validate_layout(meta.variables, limits)
  if width != meta.row_width ||
    observation_start < 0L ||
    observation_start % 80L != 0L ||
    boundary < observation_start ||
    boundary > limits.max_input_bytes ||
    tail.length() > 79 {
    v5_fail(
      "structure",
      "E_V5_INVALID_DESCRIPTOR",
      "invalid layout or boundary range",
      offset=boundary,
      dataset=name,
    )
  }
  let length = boundary - observation_start
  if boundary % 80L != 0L {
    let padding_cut = match hint {
      Some(n) => n >= 0L && (width == 0 || n <= length / width.to_int64())
      None => false
    }
    v5_fail(
      "truncated",
      if padding_cut {
        "E_V5_TRUNCATED_PADDING"
      } else {
        "E_V5_TRUNCATED_OBSERVATION"
      },
      "partial 80-byte physical record",
      offset=boundary,
      dataset=name,
    )
  }
  if hint is Some(n) {
    if n < 0L ||
      n > limits.max_rows ||
      (width == 0 && n != 0L) ||
      (width > 0 && n > limits.max_input_bytes / width.to_int64()) {
      v5_fail(
        "limit",
        "E_V5_RESOURCE_LIMIT",
        "row hint exceeds arithmetic/resource bounds",
        offset=boundary,
        dataset=name,
      )
    }
  } else if row_policy == RequireExplicitCount {
    v5_fail(
      "policy",
      "E_V5_ROW_COUNT_REQUIRED",
      "explicit member row count required",
      offset=observation_start,
      dataset=name,
    )
  }
  let counts : Array[Int64] = []
  let pads : Array[Int32] = []
  if width == 0 {
    if length == 0L {
      counts.push(0L)
      pads.push(0)
    }
  } else {
    for p = 0; p < 80 && p.to_int64() <= length; p = p + 1 {
      if p > 0 {
        if p > tail.length() {
          break
        }
        let byte = tail[tail.length() - p]
        if byte != b' ' &&
          !(padding_policy == CompatibilityNulPadding && byte == b'\x00') {
          break
        }
      }
      let data = length - p.to_int64()
      if data % width.to_int64() == 0L {
        let n = data / width.to_int64()
        if n <= limits.max_rows && (hint is None || hint == Some(n)) {
          counts.push(n)
          pads.push(p)
        }
      }
    }
  }
  if counts.is_empty() {
    v5_fail(
      if hint is Some(_) {
        "structure"
      } else {
        "truncated"
      },
      if hint is Some(_) {
        "E_V5_ROW_COUNT_HINT_MISMATCH"
      } else {
        "E_V5_INVALID_PADDING"
      },
      "no complete observations with legal minimal padding; hint=" +
      @debug.to_string(hint),
      offset=boundary,
      dataset=name,
    )
  }
  let unique = counts.length() == 1
  {
    row_count: if unique {
      Some(counts[0])
    } else {
      None
    },
    row_count_status: if !unique {
      "ambiguous"
    } else if hint is Some(_) {
      "provided"
    } else {
      "inferred"
    },
    boundary_status: "validated",
    candidate_counts: counts,
    padding_bytes: if unique {
      Some(pads[0])
    } else {
      None
    },
    padding_kind: if padding_policy == StrictSpec {
      "ascii_space"
    } else {
      "space_or_nul_compatibility"
    },
    alignment_ok: true,
    observation_start,
    boundary_offset: boundary,
    code: if unique {
      None
    } else {
      Some("E_V5_ROW_COUNT_AMBIGUOUS")
    },
  }
}
