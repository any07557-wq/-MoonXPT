///|
/// Deterministic MoonXPT-produced inputs. This program never invokes SAS.
fn cases() -> Array[(@xpt.DatasetMetadata, Array[Array[@xpt.Value]])] raise {
  let number = @xpt.VariableMetadata::new(
    "N",
    @xpt.Number,
    8,
    0,
    label=b"Numeric measurement",
  )
  let number = {
    ..number,
    format: { name: b"BEST", width: 12, decimals: 2, justification: 1, },
    informat: { name: b"BEST", width: 12, decimals: 0, justification: 0, },
  }
  let a = @xpt.DatasetMetadata::new(
    "TEST_A",
    [
      number,
      @xpt.VariableMetadata::new(
        "TXT",
        @xpt.Text,
        12,
        8,
        number=2,
        label=b"Text bytes",
      ),
    ],
    label=b"Numeric and character",
  )
  let b = @xpt.DatasetMetadata::new(
    "TEST_B",
    [
      @xpt.VariableMetadata::new("CODE", @xpt.Text, 3, 0),
      @xpt.VariableMetadata::new("VALUE", @xpt.Number, 8, 3, number=2),
    ],
    label=b"Different schema",
  )
  let tags : Array[Array[@xpt.Value]] = []
  for n = 0; n < 256; n = n + 1 {
    if @xpt.valid_missing(n.to_byte()) {
      tags.push([@xpt.Numeric(@xpt.Missing(n.to_byte()))])
    }
  }
  [
    (
      a,
      [
        [@xpt.Numeric(@xpt.Finite(1.25)), @xpt.Character(b"alpha")],
        [@xpt.Numeric(@xpt.Finite(-3.5)), @xpt.Character(b"a,b")],
        [@xpt.Numeric(@xpt.Missing(b'.')), @xpt.Character(b"tail  ")],
      ],
    ),
    (
      b,
      [
        [@xpt.Character(b"X1"), @xpt.Numeric(@xpt.Finite(0.0))],
        [@xpt.Character(b"Y2"), @xpt.Numeric(@xpt.Finite(123.0))],
      ],
    ),
    (
      @xpt.DatasetMetadata::new("EMPTY", [
        @xpt.VariableMetadata::new("X", @xpt.Number, 8, 0),
      ]),
      [],
    ),
    (
      @xpt.DatasetMetadata::new("SHORT", [
        @xpt.VariableMetadata::new("TEXT", @xpt.Text, 4, 0),
      ]),
      [[@xpt.Character(b"ABCD")], [@xpt.Character(b"    ")]],
    ),
    (
      @xpt.DatasetMetadata::new("FULLBL", [
        @xpt.VariableMetadata::new("TEXT", @xpt.Text, 80, 0),
      ]),
      [[@xpt.Character(Bytes::make(80, b' '))]],
    ),
    (
      @xpt.DatasetMetadata::new("TAGS", [
        @xpt.VariableMetadata::new("VALUE", @xpt.Number, 8, 0),
      ]),
      tags,
    ),
  ]
}

///|
fn emit(path : String, selected : String?) -> @xpt.WriteReport raise {
  let stage = @platform.Stage::new(path)
  defer stage.cleanup()
  let writer = @xpt.Writer::new(
    stage.output(),
    tail_policy=@xpt.AllowAmbiguousTail,
  )
  for (meta, rows) in cases() {
    if selected is None ||
      selected == Some(@xpt.text_field(meta.name, @xpt.Ascii)) ||
      (
        selected == Some("__REGULAR__") &&
        meta.name != b"SHORT" &&
        meta.name != b"FULLBL"
      ) {
      writer.begin_dataset(meta)
      for row in rows {
        writer.write_row(row)
      }
    }
  }
  let report = writer.finish_report()
  @platform.commit_group([stage])
  report
}

///|
fn main {
  try {
    let args = @env.args()
    if args.length() != 2 {
      @xpt.fail(
        "usage", "interop-driver NEW_OUTPUT_DIRECTORY (must already exist)",
      )
    }
    for (meta, _) in cases() {
      ignore(
        emit(
          args[1] + "/" + @xpt.text_field(meta.name, @xpt.Ascii) + ".xpt",
          Some(@xpt.text_field(meta.name, @xpt.Ascii)),
        ),
      )
    }
    ignore(emit(args[1] + "/moon_regular.xpt", Some("__REGULAR__")))
    let report = emit(args[1] + "/moon_multi.xpt", None)
    let result : Json = {
      "producer": "MoonXPT 0.2.0 development",
      "member_count": report.member_count,
      "row_count": @exchange.integer_json(report.row_count),
      "sas_executed": false,
    }
    println(result.stringify())
  } catch {
    @xpt.XptError(d) => {
      @platform.stderr(@exchange.diagnostic_json(d).stringify() + "\n")
      @platform.exit(2)
    }
    e => {
      @platform.stderr("interop driver error: " + e.to_string() + "\n")
      @platform.exit(4)
    }
  }
}
