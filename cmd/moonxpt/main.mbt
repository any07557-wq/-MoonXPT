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
        @json.to_json(rows)
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
      _ =>
        @xpt.fail(
          "usage", "this command is being implemented in the next milestone",
        )
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
