// 真实语料黄金测试：读取 tests/fixtures 下的字幕文件，对比字幕条数与问题数。

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
fn parse_int(raw : String) -> Int? {
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
fn read_text(path : String) -> Result[String, String] {
  Ok(@fs.read_file_to_string(path)) catch { _ => Err("读取失败: \{path}") }
}

///|
fn main {
  let manifest = match read_text("tests/fixtures/manifest.txt") {
    Ok(text) => text
    Err(message) => {
      println(message)
      @sys.exit(2)
      ""
    }
  }
  let failures : Array[String] = []
  let mut total = 0
  for line in split_char(manifest, '\n') {
    if line.trim().is_empty() {
      continue
    }
    let fields = split_char(line.trim().to_owned(), '|')
    if fields.length() != 3 {
      failures.push("manifest 格式错误: \{line}")
      continue
    }
    let file = "tests/fixtures/" + fields[0]
    let text = match read_text(file) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        ""
      }
    }
    let subtitle = match @lib.parse_srt(text) {
      Ok(value) => value
      Err(message) => {
        failures.push("\{fields[0]}: 解析失败 \{message}")
        @lib.empty_subtitle()
      }
    }
    let issues = @lib.validate(subtitle, @lib.ValidateOptions::new())
    total = total + 1
    match (parse_int(fields[1]), parse_int(fields[2])) {
      (Some(expected_cues), Some(expected_issues)) => {
        if subtitle.cues.length() != expected_cues {
          failures.push(
            "\{fields[0]}: expected \{expected_cues} cues, got \{subtitle.cues.length()}",
          )
        }
        if issues.length() != expected_issues {
          failures.push(
            "\{fields[0]}: expected \{expected_issues} issues, got \{issues.length()}",
          )
        }
      }
      _ => failures.push("\{fields[0]}: manifest 数字无效")
    }
  }
  if failures.length() == 0 {
    println("golden: \{total} fixtures passed")
    @sys.exit(0)
  } else {
    for failure in failures {
      println("FAIL \{failure}")
    }
    println("golden: \{failures.length()} / \{total} failed")
    @sys.exit(1)
  }
}
