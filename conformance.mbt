// 一致性语料：解析、序列化、变换与校验的单一事实来源。

///|
fn check(failures : Array[String], name : String, condition : Bool) -> Unit {
  if !condition {
    failures.push(name)
  }
}

///|
fn parse_srt_ok(text : String) -> Subtitle? {
  match parse_srt(text) {
    Ok(subtitle) => Some(subtitle)
    Err(_) => None
  }
}

///|
fn parse_vtt_ok(text : String) -> Subtitle? {
  match parse_vtt(text) {
    Ok(subtitle) => Some(subtitle)
    Err(_) => None
  }
}

///|
const SAMPLE_SRT : String = "1\n00:00:01,000 --> 00:00:04,000\nHello\n\n2\n00:00:05,000 --> 00:00:08,000\nWorld\n"

///|
const SAMPLE_VTT : String = "WEBVTT\n\n1\n00:00:01.000 --> 00:00:04.000\nHello\n\n2\n00:00:05.000 --> 00:00:08.000\nWorld\n"

///|
/// 一致性语料条数。
pub fn conformance_case_count() -> Int {
  17
}

///|
/// 运行一致性语料，返回失败描述（空数组表示全部通过）。
pub fn run_conformance() -> Array[String] {
  let failures : Array[String] = []
  let simple = "1\n00:00:01,000 --> 00:00:04,000\nHello\n"
  match parse_srt_ok(simple) {
    None => failures.push("parse-simple: 解析失败")
    Some(subtitle) => {
      check(failures, "parse-simple: 条数", subtitle.cues.length() == 1)
      check(failures, "parse-simple: 开始", subtitle.cues[0].start_ms == 1000)
      check(failures, "parse-simple: 结束", subtitle.cues[0].end_ms == 4000)
      check(failures, "parse-simple: 文本", subtitle.cues[0].text == "Hello")
    }
  }
  match parse_srt_ok(SAMPLE_SRT) {
    None => failures.push("parse-two: 解析失败")
    Some(subtitle) => {
      check(failures, "parse-two: 条数", subtitle.cues.length() == 2)
      check(
        failures,
        "parse-two: 第二条开始",
        subtitle.cues[1].start_ms == 5000,
      )
    }
  }
  let multiline = "1\n00:00:01,000 --> 00:00:04,000\nline one\nline two\n"
  match parse_srt_ok(multiline) {
    None => failures.push("parse-multiline: 解析失败")
    Some(subtitle) =>
      check(
        failures,
        "parse-multiline: 文本",
        subtitle.cues[0].text == "line one\nline two",
      )
  }
  match
    parse_srt_ok("\u{feff}1\r\n00:00:01,000 --> 00:00:04,000\r\nHello\r\n") {
    None => failures.push("parse-bom-crlf: 解析失败")
    Some(subtitle) =>
      check(
        failures,
        "parse-bom-crlf: 文本",
        subtitle.cues[0].text == "Hello",
      )
  }
  match parse_srt_ok(SAMPLE_SRT) {
    None => failures.push("roundtrip: 解析失败")
    Some(subtitle) => {
      let roundtrip = parse_srt_ok(serialize_srt(subtitle))
      match roundtrip {
        None => failures.push("roundtrip: 二次解析失败")
        Some(again) =>
          check(failures, "roundtrip: 条数", again.cues.length() == 2)
      }
    }
  }
  match parse_vtt_ok(SAMPLE_VTT) {
    None => failures.push("vtt-parse: 解析失败")
    Some(subtitle) =>
      check(failures, "vtt-parse: 条数", subtitle.cues.length() == 2)
  }
  match parse_vtt_ok(SAMPLE_VTT) {
    None => failures.push("vtt-serialize: 解析失败")
    Some(subtitle) => {
      let output = serialize_vtt(subtitle)
      check(failures, "vtt-serialize: 头", output.has_prefix("WEBVTT\n\n"))
      check(failures, "vtt-serialize: 点号", output.contains("00:00:01.000"))
    }
  }
  match parse_srt_ok(SAMPLE_SRT) {
    None => failures.push("shift: 解析失败")
    Some(subtitle) => {
      let moved = shift(subtitle, 1500)
      check(failures, "shift: 开始", moved.cues[0].start_ms == 2500)
      check(failures, "shift: 结束", moved.cues[0].end_ms == 5500)
    }
  }
  match parse_srt_ok(simple) {
    None => failures.push("shift-clamp: 解析失败")
    Some(subtitle) => {
      let moved = shift(subtitle, -5000)
      check(failures, "shift-clamp: 不为负", moved.cues[0].start_ms == 0)
    }
  }
  match parse_srt_ok(simple) {
    None => failures.push("scale: 解析失败")
    Some(subtitle) => {
      let scaled = scale(subtitle, 200)
      check(failures, "scale: 开始", scaled.cues[0].start_ms == 2000)
      check(failures, "scale: 结束", scaled.cues[0].end_ms == 8000)
    }
  }
  let overlap = "1\n00:00:01,000 --> 00:00:05,000\nA\n\n2\n00:00:04,000 --> 00:00:08,000\nB\n"
  match parse_srt_ok(overlap) {
    None => failures.push("validate-overlap: 解析失败")
    Some(subtitle) => {
      let issues = validate(subtitle, ValidateOptions::new())
      let mut found = false
      for issue in issues {
        if issue_kind_name(issue.kind) == "overlap" {
          found = true
        }
      }
      check(failures, "validate-overlap: 检出", found)
      let fixed = resolve_overlaps(subtitle, 100)
      let fixed_issues = validate(fixed, ValidateOptions::new())
      let mut still_overlap = false
      for issue in fixed_issues {
        if issue_kind_name(issue.kind) == "overlap" {
          still_overlap = true
        }
      }
      check(failures, "resolve-overlap: 已消除", !still_overlap)
    }
  }
  let empty = "1\n00:00:01,000 --> 00:00:04,000\n   \n"
  match parse_srt_ok(empty) {
    None => failures.push("validate-empty: 解析失败")
    Some(subtitle) => {
      let issues = validate(subtitle, ValidateOptions::new())
      let mut found = false
      for issue in issues {
        if issue_kind_name(issue.kind) == "empty-text" {
          found = true
        }
      }
      check(failures, "validate-empty: 检出", found)
    }
  }
  let short = "1\n00:00:01,000 --> 00:00:01,200\nA\n"
  match parse_srt_ok(short) {
    None => failures.push("validate-short: 解析失败")
    Some(subtitle) => {
      let issues = validate(subtitle, ValidateOptions::new())
      let mut found = false
      for issue in issues {
        if issue_kind_name(issue.kind) == "too-short" {
          found = true
        }
      }
      check(failures, "validate-short: 检出", found)
    }
  }
  let long_line = "1\n00:00:01,000 --> 00:00:05,000\n\{long_text()}\n"
  match parse_srt_ok(long_line) {
    None => failures.push("validate-long: 解析失败")
    Some(subtitle) => {
      let issues = validate(subtitle, ValidateOptions::new())
      let mut found = false
      for issue in issues {
        if issue_kind_name(issue.kind) == "line-too-long" {
          found = true
        }
      }
      check(failures, "validate-long: 检出", found)
    }
  }
  match parse_srt("1\nnot-a-timestamp\nHello\n") {
    Ok(_) => failures.push("invalid-timestamp: 不应解析成功")
    Err(_) => ()
  }
  match parse_srt_ok("1\n01:02:03,004 --> 01:02:04,005\nA\n") {
    None => failures.push("format: 解析失败")
    Some(subtitle) =>
      check(
        failures,
        "format: SRT 时间",
        serialize_srt(subtitle).contains("01:02:03,004"),
      )
  }
  match
    parse_vtt(
      "WEBVTT\n\nNOTE a comment\n\n1\n00:00:01.000 --> 00:00:04.000\nHello\n",
    ) {
    Err(_) => failures.push("vtt-note: 解析失败")
    Ok(subtitle) =>
      check(failures, "vtt-note: 跳过 NOTE", subtitle.cues.length() == 1)
  }
  failures
}

///|
fn long_text() -> String {
  let builder = StringBuilder()
  let mut i = 0
  while i < 60 {
    builder.write_string("x")
    i = i + 1
  }
  builder.to_string()
}
