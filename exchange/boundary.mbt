///|
pub fn boundary_json(report : @xpt.BoundaryReport) -> Json {
  let diagnostics : Array[Json] = match report.code {
    Some(code) => [{ "code": code }]
    None => []
  }
  {
    "row_count": report.row_count.map(integer_json).unwrap_or(Json::null()),
    "row_count_status": report.row_count_status,
    "hint": report.hint.map(integer_json).unwrap_or(Json::null()),
    "expected_bytes": report.expected_bytes
    .map(integer_json)
    .unwrap_or(Json::null()),
    "actual_bytes": integer_json(report.actual_bytes),
    "policy": report.policy,
    "boundary_status": report.boundary_status,
    "candidate_counts": report.candidate_counts.map(integer_json),
    "padding_bytes": report.padding_bytes
    .map(n => Json::number(n.to_double()))
    .unwrap_or(Json::null()),
    "padding_kind": report.padding_kind,
    "alignment_ok": report.alignment_ok,
    "observation_start": integer_json(report.observation_start),
    "boundary_offset": integer_json(report.boundary_offset),
    "diagnostics": diagnostics,
  }
}

///|
/// Additive machine diagnostics; old kind/reason/offset fields are retained.
pub fn boundary_diagnostic_json(
  d : @xpt.Diagnostic,
  report : @xpt.BoundaryReport?,
) -> Json {
  {
    "kind": d.kind,
    "code": d.code(),
    "reason": d.reason,
    "offset": d.offset.map(integer_json).unwrap_or(Json::null()),
    "member": d.dataset.map(Json::string).unwrap_or(Json::null()),
    "row": d.row.map(integer_json).unwrap_or(Json::null()),
    "variable": d.variable.map(Json::string).unwrap_or(Json::null()),
    "boundary": report.map(boundary_json).unwrap_or(Json::null()),
  }
}
