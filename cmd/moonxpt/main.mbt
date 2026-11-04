///|
fn help() -> String {
  (
    #|MoonXPT 0.1 — SAS XPORT V5 (native)
    #|Usage:
    #|  moonxpt inspect INPUT.xpt [--json] [--count-rows]
    #|  moonxpt export INPUT.xpt --member NAME --csv DATA.csv --metadata DATA.json
    #|  moonxpt write DATA.csv --metadata DATA.json --output OUTPUT.xpt
    #|Options:
    #|  --encoding ascii|windows-1252  Explicit source text encoding (default ascii)
    #|  --tail-policy strict|trim      Default strict; trim chooses maximal legal padding
    #|  --rows MEMBER=COUNT            Repeatable exact row hints for ambiguous V5 files
    #|  --max-input-bytes N            Default 1099511627776
    #|  --max-row-bytes N              Default 16777216
    #|  --force                        Replace outputs using staged files
    #|  --numeric-empty-missing        Treat empty numeric CSV fields as '.' on import
    #|  --help                         Show help
    #|Exit codes: 0 success, 2 usage/format/schema, 3 I/O, 4 unexpected failure.
  )
}

///|
struct Args {
  command : String
  input : String
  opts : Map[String, String]
  flags : Map[String, Bool]
  read_options : @xpt.ReadOptions
  encoding : @xpt.Encoding
}

///|
fn positive_integer(raw : String) -> Int64 raise @xpt.XptError {
  let n = @string.parse_int64(raw[:]) catch {
    _ => @xpt.fail("usage", "expected nonnegative integer: \{raw}")
  }
  if n < 0L {
    @xpt.fail("usage", "integer must be nonnegative")
  }
  n
}

///|
fn parse_args(args : Array[String]) -> Args raise @xpt.XptError {
  if args.length() < 3 {
    @xpt.fail("usage", "command and input path are required; use --help")
  }
  let command = args[1]
  if !["inspect", "export", "write"].contains(command) {
    @xpt.fail("usage", "unknown command: \{command}")
  }
  let opts : Map[String, String] = Map([])
  let flags : Map[String, Bool] = Map([])
  let hints : Map[String, Int64] = Map([])
  let mut i = 3
  while i < args.length() {
    let key = args[i]
    if ["--json", "--count-rows", "--force", "--numeric-empty-missing"].contains(
        key,
      ) {
      if flags.contains(key) {
        @xpt.fail("usage", "duplicate option: \{key}")
      }
      flags[key] = true
      i = i + 1
    } else if [
        "--member", "--csv", "--metadata", "--output", "--encoding", "--tail-policy",
        "--rows", "--max-input-bytes", "--max-row-bytes",
      ].contains(key) {
      if i + 1 >= args.length() {
        @xpt.fail("usage", "option requires a value: \{key}")
      }
      if key == "--rows" {
        match args[i + 1].split_once("=") {
          Some((name, count)) => {
            let name = name.to_owned()
            if name.is_empty() || hints.contains(name) {
              @xpt.fail("usage", "invalid or duplicate member row hint")
            }
            hints[name] = positive_integer(count.to_owned())
          }
          None => @xpt.fail("usage", "--rows requires MEMBER=COUNT")
        }
      } else {
        if opts.contains(key) {
          @xpt.fail("usage", "duplicate option: \{key}")
        }
        opts[key] = args[i + 1]
      }
      i = i + 2
    } else {
      @xpt.fail("usage", "unknown option: \{key}")
    }
  }
  let encoding = @exchange.parse_encoding(
    opts.get("--encoding").unwrap_or("ascii"),
  )
  let tail_policy = match opts.get("--tail-policy").unwrap_or("strict") {
    "strict" => @xpt.Reject
    "trim" => @xpt.TrimPadding
    _ => @xpt.fail("usage", "tail policy must be strict or trim")
  }
  let mut limits = @xpt.Limits::default()
  if opts.get("--max-input-bytes") is Some(raw) {
    limits = { ..limits, max_input_bytes: positive_integer(raw), }
  }
  if opts.get("--max-row-bytes") is Some(raw) {
    let n = positive_integer(raw)
    if n > 16777216L {
      @xpt.fail("usage", "row limit may not exceed 16777216")
    }
    limits = { ..limits, max_row_bytes: n.to_int(), }
  }
  {
    command,
    input: args[2],
    opts,
    flags,
    encoding,
    read_options: { limits, tail_policy, row_hints: hints, },
  }
}

///|
fn inspect_file(args : Args) -> Unit raise {
  for key in ["--member", "--csv", "--metadata", "--output"] {
    if args.opts.contains(key) {
      @xpt.fail("usage", "\{key} is not valid for inspect")
    }
  }
  let file = @platform.File::open(args.input)
  defer file.cleanup()
  let reader = @xpt.Reader::new(file.input(), options=args.read_options)
  let members : Array[Json] = []
  let count = args.flags.contains("--count-rows")
  while reader.next_dataset() is Some(meta) {
    let mut rows = 0L
    while reader.next_raw() is Some(_) {
      rows = rows + 1L
    }
    members.push({
      "metadata": @exchange.dataset_json(meta, args.encoding),
      "row_count": if count {
        @exchange.integer_json(rows)
      } else {
        Json::null()
      },
    })
  }
  let report : Json = {
    "format": "XPORT",
    "version": 5,
    "encoding": @exchange.encoding_name(args.encoding),
    "tail_policy": if args.read_options.tail_policy == @xpt.Reject {
      "strict"
    } else {
      "trim"
    },
    "library": @exchange.library_json(reader.library()),
    "members": members,
  }
  if args.flags.contains("--json") {
    println(report.stringify())
  } else {
    println("SAS XPORT V5; encoding=\{@exchange.encoding_name(args.encoding)}")
    for entry in members {
      println(entry.stringify(indent=2))
    }
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() == 1 || args.contains("--help") {
    println(help())
    return
  }
  try {
    let parsed = parse_args(args)
    match parsed.command {
      "inspect" => inspect_file(parsed)
      "export" => export_file(parsed)
      "write" => write_file(parsed)
      _ => @xpt.fail("usage", "unsupported command")
    }
  } catch {
    @xpt.XptError(d) => {
      @platform.stderr(@exchange.diagnostic_json(d).stringify() + "\n")
      @platform.exit(if d.kind == "io" { 3 } else { 2 })
    }
    error => {
      @platform.stderr(
        "{\"kind\":\"internal\",\"reason\":" +
        Json::string(@debug.to_string(error)).stringify() +
        "}\n",
      )
      @platform.exit(4)
    }
  }
}

///|
fn write_file(args : Args) -> Unit raise {
  let meta_path = required_option(args, "--metadata")
  let output = required_option(args, "--output")
  @platform.ensure_distinct(args.input, output)
  @platform.ensure_distinct(meta_path, output)
  let metadata = @exchange.parse_metadata(
    @platform.read_text(meta_path),
    limits=args.read_options.limits,
  )
  if args.opts.contains("--encoding") && args.encoding != metadata.encoding {
    @xpt.fail("usage", "--encoding disagrees with metadata encoding")
  }
  let input = @platform.File::open(args.input)
  defer input.cleanup()
  let csv = @exchange.CsvReader::new(
    n => input.read(n),
    max_columns=args.read_options.limits.max_variables,
    max_input_bytes=args.read_options.limits.max_input_bytes,
  )
  let header = csv
    .next_record()
    .unwrap_or_else(() => @xpt.fail("csv", "CSV header is missing"))
  let names : Array[String] = []
  for v in metadata.dataset.variables {
    names.push(@xpt.text_field(v.name, @xpt.Ascii))
  }
  if !(names.is_empty() && header == [""]) && header != names {
    @xpt.fail("csv", "CSV header names/order do not match metadata")
  }
  let stage = @platform.Stage::new(output, force=args.flags.contains("--force"))
  defer stage.cleanup()
  let writer = @xpt.Writer::new(stage.output(), library=metadata.library, options={
    ..@xpt.WriteOptions::default(),
    limits: args.read_options.limits,
  })
  writer.begin_dataset(metadata.dataset)
  let mut count = 0L
  while true {
    let offset = csv.offset()
    let cells = csv.next_record()
    if cells is None {
      break
    }
    if count >= metadata.row_count {
      @xpt.fail(
        "csv",
        "CSV contains more rows than metadata row_count",
        offset~,
        row=count,
      )
    }
    writer.write_row(
      @exchange.import_cells(
        metadata.dataset,
        cells.unwrap(),
        metadata.encoding,
        numeric_empty_missing=args.flags.contains("--numeric-empty-missing"),
      ),
    ) catch {
      @xpt.XptError(d) =>
        raise @xpt.XptError({
          ..d,
          offset: Some(d.offset.unwrap_or(offset)),
          row: Some(d.row.unwrap_or(count)),
          dataset: Some(@xpt.text_field(metadata.dataset.name, @xpt.Ascii)),
        })
      e => raise e
    }
    count = count + 1L
  }
  if count != metadata.row_count {
    @xpt.fail("csv", "CSV row count differs from metadata row_count", row=count)
  }
  writer.finish()
  @platform.commit_group([stage])
  let report : Json = {
    "output": output,
    "row_count": @exchange.integer_json(count),
    "member": @xpt.text_field(metadata.dataset.name, @xpt.Ascii),
  }
  println(report.stringify())
}

///|
fn required_option(args : Args, key : String) -> String raise @xpt.XptError {
  args.opts
  .get(key)
  .unwrap_or_else(() => @xpt.fail("usage", "required option: \{key}"))
}

///|
fn export_file(args : Args) -> Unit raise {
  let selected = required_option(args, "--member")
  let csv_path = required_option(args, "--csv")
  let meta_path = required_option(args, "--metadata")
  @platform.ensure_distinct(args.input, csv_path)
  @platform.ensure_distinct(args.input, meta_path)
  @platform.ensure_distinct(csv_path, meta_path)
  let input = @platform.File::open(args.input)
  defer input.cleanup()
  let csv = @platform.Stage::new(csv_path, force=args.flags.contains("--force"))
  defer csv.cleanup()
  let metadata = @platform.Stage::new(
    meta_path,
    force=args.flags.contains("--force"),
  )
  defer metadata.cleanup()
  let reader = @xpt.Reader::new(input.input(), options=args.read_options)
  let mut found = false
  let mut count = 0L
  while reader.next_dataset() is Some(meta) {
    if @xpt.text_field(meta.name, @xpt.Ascii) == selected {
      found = true
      csv.write(@exchange.csv_header(meta))
      while reader.next_row() is Some(row) {
        csv.write(@exchange.csv_record(@exchange.row_cells(row, args.encoding)))
        count = count + 1L
      }
      let json = @exchange.metadata_json(
        reader.library(),
        meta,
        args.encoding,
        count,
      )
      metadata.write_text(json.stringify() + "\n")
    } else {
      while reader.next_raw() is Some(_) {
        ()
      }
    }
  }
  if !found {
    @xpt.fail("member", "member not found: \{selected}")
  }
  @platform.commit_group([csv, metadata])
  let report : Json = {
    "member": selected,
    "row_count": @exchange.integer_json(count),
    "csv": csv_path,
    "metadata": meta_path,
  }
  println(report.stringify())
}
