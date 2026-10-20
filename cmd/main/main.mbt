// mbt-subtitle 命令行入口。

///|
const VERSION : String = "0.1.0"

///|
fn usage() -> String {
  let s = StringBuilder()
  s.write_string("mbt-subtitle \{VERSION} — SRT / WebVTT 字幕工具\n\n")
  s.write_string("用法:\n")
  s.write_string("  mbt-subtitle check <文件> [--json]\n")
  s.write_string(
    "  mbt-subtitle shift <文件> --by <1.5s|500ms|00:00:01.500> [--output <文件>]\n",
  )
  s.write_string(
    "  mbt-subtitle scale <文件> --percent <整数> [--output <文件>]\n",
  )
  s.write_string(
    "  mbt-subtitle fix <文件> [--gap 100ms] [--output <文件>]\n",
  )
  s.write_string(
    "  mbt-subtitle convert <文件> --to <srt|vtt> [--output <文件>]\n\n",
  )
  s.write_string("选项:\n")
  s.write_string("  -v, --version  显示版本\n")
  s.write_string("  -h, --help     显示本帮助\n\n")
  s.write_string(
    "退出码:\n  0  成功\n  1  check 发现问题\n  2  用法或读写错误\n",
  )
  s.to_string()
}

///|
struct Options {
  mut command : String?
  mut file : String?
  mut by : String?
  mut percent : Int?
  mut gap : String?
  mut to : String?
  mut output : String?
  mut json : Bool
  mut help : Bool
  mut version : Bool
}

///|
fn Options::new() -> Options {
  {
    command: None,
    file: None,
    by: None,
    percent: None,
    gap: None,
    to: None,
    output: None,
    json: false,
    help: false,
    version: false,
  }
}

///|
fn output(text : String) -> Unit {
  let chars = text.iter().to_array()
  let mut n = chars.length()
  while n > 0 && (chars[n - 1] == '\n' || chars[n - 1] == '\r') {
    n = n - 1
  }
  if n == 0 {
    return
  }
  let buffer = StringBuilder()
  for i = 0; i < n; i = i + 1 {
    buffer.write_char(chars[i])
  }
  println(buffer.to_string())
}

///|
fn usage_error(message : String) -> Unit {
  println("错误: \{message}")
  println("")
  output(usage())
  @sys.exit(2)
}

///|
fn next_arg(args : Array[String], i : Int, name : String) -> String {
  if i + 1 >= args.length() {
    usage_error("\{name} 需要一个参数")
  }
  args[i + 1]
}

///|
fn parse_uint(raw : String) -> Int? {
  if raw.is_empty() {
    return None
  }
  let mut value = 0
  for c in raw {
    if !c.is_ascii_digit() {
      return None
    }
    value = value * 10 + (c.to_int() - 48)
  }
  Some(value)
}

///|
fn parse_args(args : Array[String]) -> Options {
  let options = Options::new()
  let positional : Array[String] = []
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--json" => options.json = true
      "--by" => {
        options.by = Some(next_arg(args, i, "--by"))
        i = i + 1
      }
      "--percent" => {
        options.percent = parse_uint(next_arg(args, i, "--percent"))
        i = i + 1
      }
      "--gap" => {
        options.gap = Some(next_arg(args, i, "--gap"))
        i = i + 1
      }
      "--to" => {
        options.to = Some(next_arg(args, i, "--to"))
        i = i + 1
      }
      "--output" => {
        options.output = Some(next_arg(args, i, "--output"))
        i = i + 1
      }
      "--help" | "-h" => options.help = true
      "--version" | "-v" => options.version = true
      _ =>
        if arg.has_prefix("-") {
          usage_error("未知选项「\{arg}」")
        } else {
          positional.push(arg)
        }
    }
    i = i + 1
  }
  if positional.length() > 0 {
    options.command = Some(positional[0])
  }
  if positional.length() > 1 {
    options.file = Some(positional[1])
  }
  if positional.length() > 2 {
    usage_error("参数过多")
  }
  options
}

///|
fn ascii_lower(s : String) -> String {
  let buffer = StringBuilder()
  for c in s {
    buffer.write_char(c.to_ascii_lowercase())
  }
  buffer.to_string()
}

///|
fn format_of_path(path : String) -> @lib.SubtitleFormat {
  if ascii_lower(path).has_suffix(".vtt") {
    @lib.Vtt
  } else {
    @lib.Srt
  }
}

///|
fn format_of_name(name : String) -> @lib.SubtitleFormat? {
  match ascii_lower(name) {
    "srt" => Some(@lib.Srt)
    "vtt" => Some(@lib.Vtt)
    _ => None
  }
}

///|
fn read_text(path : String) -> Result[String, String] {
  Ok(@fs.read_file_to_string(path)) catch {
    _ => Err("读取文件失败")
  }
}

///|
fn load_subtitle(path : String) -> Result[@lib.Subtitle, String] {
  match read_text(path) {
    Err(message) => Err(message)
    Ok(text) => @lib.parse_subtitle(text, format_of_path(path))
  }
}

///|
fn write_result(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    _ => {
      println("无法写入「\{path}」")
      @sys.exit(2)
    }
  }
}

///|
fn emit_result(options : Options, content : String) -> Unit {
  match options.output {
    Some(path) => write_result(path, content)
    None => output(content)
  }
}

///|
fn split_char(text : String, separator : Char) -> Array[String] {
  let parts : Array[String] = []
  let buffer = StringBuilder()
  for c in text {
    if c == separator {
      parts.push(buffer.to_string())
      buffer.reset()
    } else {
      buffer.write_char(c)
    }
  }
  parts.push(buffer.to_string())
  parts
}

///|
fn chars_from(text : String, start : Int) -> String {
  let chars = text.iter().to_array()
  let buffer = StringBuilder()
  let mut i = start
  while i < chars.length() {
    buffer.write_char(chars[i])
    i = i + 1
  }
  buffer.to_string()
}

///|
fn parse_seconds(raw : String) -> Int? {
  let parts = split_char(raw, '.')
  let whole = match parse_uint(parts[0]) {
    Some(value) => value
    None => return None
  }
  let millis = if parts.length() > 1 {
    let fraction = parts[1]
    if fraction.length() > 3 {
      return None
    }
    let padded = if fraction.length() == 1 {
      fraction + "00"
    } else if fraction.length() == 2 {
      fraction + "0"
    } else {
      fraction
    }
    match parse_uint(padded) {
      Some(value) => value
      None => return None
    }
  } else {
    0
  }
  Some(whole * 1000 + millis)
}

///|
fn parse_duration(raw : String) -> Int? {
  let negative = raw.has_prefix("-")
  let body = if negative { chars_from(raw, 1) } else { raw }
  let millis = if body.has_suffix("ms") {
    let chars = body.iter().to_array()
    parse_uint(chars_to_string(chars, 0, chars.length() - 2))
  } else if body.has_suffix("s") {
    let chars = body.iter().to_array()
    parse_seconds(chars_to_string(chars, 0, chars.length() - 1))
  } else {
    @lib.parse_timecode(body)
  }
  match millis {
    None => None
    Some(value) => if negative { Some(-value) } else { Some(value) }
  }
}

///|
fn chars_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let buffer = StringBuilder()
  let mut i = start
  while i < end && i < chars.length() {
    buffer.write_char(chars[i])
    i = i + 1
  }
  buffer.to_string()
}

///|
fn json_escape(s : String) -> String {
  let builder = StringBuilder()
  for c in s {
    match c {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(c)
    }
  }
  builder.to_string()
}

///|
fn report_json(
  subtitle : @lib.Subtitle,
  issues : Array[@lib.Issue],
) -> String {
  let builder = StringBuilder()
  builder.write_string("{\"cues\":")
  builder.write_string(subtitle.cues.length().to_string())
  builder.write_string(",\"issues\":[")
  let mut first = true
  for issue in issues {
    if !first {
      builder.write_string(",")
    }
    builder.write_string("{\"kind\":\"")
    builder.write_string(@lib.issue_kind_name(issue.kind))
    builder.write_string("\",\"cue\":")
    builder.write_string(issue.cue_index.to_string())
    builder.write_string(",\"message\":\"")
    builder.write_string(json_escape(issue.message))
    builder.write_string("\"}")
    first = false
  }
  builder.write_string("]}")
  builder.to_string()
}

///|
fn main {
  let args = @env.args()
  let options = parse_args(args)
  if options.help {
    output(usage())
    @sys.exit(0)
    return
  }
  if options.version {
    println("mbt-subtitle \{VERSION}")
    @sys.exit(0)
    return
  }
  let command = match options.command {
    Some(value) => value
    None => {
      usage_error("缺少命令")
      ""
    }
  }
  let path = match options.file {
    Some(value) => value
    None => {
      usage_error("缺少文件参数")
      ""
    }
  }
  let subtitle = match load_subtitle(path) {
    Ok(value) => value
    Err(message) => {
      println("无法解析「\{path}」: \{message}")
      @sys.exit(2)
      @lib.empty_subtitle()
    }
  }
  match command {
    "check" => {
      let issues = @lib.validate(subtitle, @lib.ValidateOptions::new())
      if options.json {
        let json = report_json(subtitle, issues)
        match options.output {
          Some(path) => write_result(path, json)
          None => output(json)
        }
      } else if issues.length() == 0 {
        println("check: \{subtitle.cues.length()} 条字幕，未发现问题")
      } else {
        println(
          "check: \{subtitle.cues.length()} 条字幕，发现 \{issues.length()} 个问题",
        )
        for issue in issues {
          println(
            "  cue \{issue.cue_index}: \{@lib.issue_kind_name(issue.kind)} — \{issue.message}",
          )
        }
      }
      if issues.length() > 0 {
        @sys.exit(1)
      } else {
        @sys.exit(0)
      }
    }
    "shift" => {
      let by = match options.by {
        Some(value) => value
        None => {
          usage_error("shift 需要 --by 参数")
          ""
        }
      }
      let delta = match parse_duration(by) {
        Some(value) => value
        None => {
          usage_error("无法解析 --by「\{by}」")
          0
        }
      }
      let moved = @lib.shift(subtitle, delta)
      emit_result(options, @lib.serialize_subtitle(moved, format_of_path(path)))
      @sys.exit(0)
    }
    "scale" => {
      let percent = match options.percent {
        Some(value) => value
        None => {
          usage_error("scale 需要 --percent 参数")
          0
        }
      }
      let scaled = @lib.scale(subtitle, percent)
      emit_result(
        options,
        @lib.serialize_subtitle(scaled, format_of_path(path)),
      )
      @sys.exit(0)
    }
    "fix" => {
      let gap = match options.gap {
        Some(value) =>
          match parse_duration(value) {
            Some(ms) => ms
            None => {
              usage_error("无法解析 --gap「\{value}」")
              100
            }
          }
        None => 100
      }
      let fixed = @lib.resolve_overlaps(subtitle, gap)
      emit_result(options, @lib.serialize_subtitle(fixed, format_of_path(path)))
      @sys.exit(0)
    }
    "convert" => {
      let target_name = match options.to {
        Some(value) => value
        None => {
          usage_error("convert 需要 --to 参数")
          ""
        }
      }
      let target = match format_of_name(target_name) {
        Some(value) => value
        None => {
          usage_error("--to 只支持 srt / vtt")
          @lib.Srt
        }
      }
      emit_result(options, @lib.serialize_subtitle(subtitle, target))
      @sys.exit(0)
    }
    _ => usage_error("未知命令「\{command}」")
  }
}
