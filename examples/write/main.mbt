///|
/// Demonstrate reusable multi-member writing, independent of CLI exchange.
fn main {
  try {
    let args = @env.args()
    if args.length() != 2 {
      @xpt.fail("usage", "write-example OUTPUT.xpt (must not exist)")
    }
    let file = @platform.File::create(args[1])
    defer file.cleanup()
    let writer = @xpt.Writer::new(file.output())
    let nums = @xpt.DatasetMetadata::new(
      "NUMBERS",
      [
        @xpt.VariableMetadata::new("ID", @xpt.Number, 8, 0, label=b"Identifier"),
        @xpt.VariableMetadata::new(
          "VALUE",
          @xpt.Number,
          8,
          8,
          number=2,
          label=b"Measured value",
        ),
      ],
      label=b"Numeric observations",
    )
    writer.begin_dataset(nums)
    for i = 0; i < 3; i = i + 1 {
      writer.write_row([
        @xpt.Numeric(@xpt.Finite(i.to_double() + 1.0)),
        @xpt.Numeric(@xpt.Finite((i.to_double() + 1.0) * 1.25)),
      ])
    }
    let words = @xpt.DatasetMetadata::new(
      "WORDS",
      [@xpt.VariableMetadata::new("TEXT", @xpt.Text, 16, 0)],
      label=b"Second member",
    )
    writer.begin_dataset(words)
    for text in ["hello", ".A", "a,b\"c"] {
      writer.write_row([@xpt.Character(@xpt.encode_text(text, @xpt.Ascii))])
    }
    let tags = @xpt.DatasetMetadata::new("TAGS", [
      @xpt.VariableMetadata::new("MISSING", @xpt.Number, 8, 0),
    ])
    writer.begin_dataset(tags)
    for tag = 0; tag < 256; tag = tag + 1 {
      if @xpt.valid_missing(tag.to_byte()) {
        writer.write_row([@xpt.Numeric(@xpt.Missing(tag.to_byte()))])
      }
    }
    writer.begin_dataset(
      @xpt.DatasetMetadata::new("EMPTY", [
        @xpt.VariableMetadata::new("X", @xpt.Number, 8, 0),
      ]),
    )
    writer.finish()
    file.sync()
    file.close()
    println("wrote NUMBERS(3), WORDS(3), TAGS(28), EMPTY(0)")
  } catch {
    @xpt.XptError(d) => println("ERROR \{d.kind} \{d.reason}")
    _ => println("ERROR unexpected")
  }
}
