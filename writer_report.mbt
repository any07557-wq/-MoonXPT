///|
pub(all) enum WriterTailPolicy {
  RejectAmbiguousTail
  AllowAmbiguousTail
} derive(Eq, @debug.Debug)

///|
pub(all) struct WriteMemberReport {
  member_name : String
  row_count : Int64
  padding_bytes : Int32
  code : String?
} derive(Eq, @debug.Debug)

///|
pub(all) struct WriteReport {
  member_count : Int32
  row_count : Int64
  members : Array[WriteMemberReport]
} derive(Eq, @debug.Debug)

///|
/// The legacy finish()->Unit call remains available.
pub fn Writer::finish_report(self : Writer) -> WriteReport raise {
  self.check()
  errdefer {
    self.failed = true
  }
  self.end_dataset()
  let mut total = 0L
  for entry in self.reports {
    if entry.row_count > 9223372036854775807L - total {
      v5_fail("limit", "E_V5_RESOURCE_LIMIT", "writer total row count overflow")
    }
    total = total + entry.row_count
  }
  self.finished = true
  { member_count: self.count, row_count: total, members: self.reports.copy(), }
}
