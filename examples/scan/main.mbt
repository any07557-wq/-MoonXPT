///|
/// Public API example. Explicit trim policy is a documented compatibility choice.
fn main {
  try {
    let args = @env.args()
    if args.length() < 2 || args.length() > 3 {
      @xpt.fail("usage", "scan INPUT.xpt")
    }
    let file = @platform.File::open(args[1])
    defer file.cleanup()
    let reader = @xpt.Reader::new(file.input(), options={
      ..@xpt.ReadOptions::default(),
      tail_policy: @xpt.TrimPadding,
    })
    while reader.next_dataset() is Some(meta) {
      let mut count = 0L
      let mut missing = 0L
      while reader.next_row() is Some(row) {
        count = count + 1L
        for v in row.values {
          if v is @xpt.Numeric(@xpt.Missing(_)) {
            missing = missing + 1L
          }
        }
        if args.length() == 3 && args[2] == "--values" {
          let cells : Array[String] = []
          for v in row.values {
            cells.push(
              match v {
                @xpt.Numeric(@xpt.Finite(n)) => n.to_string()
                @xpt.Numeric(@xpt.Missing(tag)) => @xpt.missing_token(tag)
                @xpt.Character(_) =>
                  @xpt.fail("usage", "numeric scan example only")
              },
            )
          }
          println(cells.join(","))
        }
      }
      println(
        "\{@xpt.text_field(meta.name,@xpt.Ascii)} rows=\{count} columns=\{meta.variables.length()} missing=\{missing}",
      )
    }
  } catch {
    @xpt.XptError(d) => println("ERROR \{d.kind} \{d.reason}")
    _ => println("ERROR unexpected")
  }
}
