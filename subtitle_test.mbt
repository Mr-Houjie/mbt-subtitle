// 黑盒测试：只通过公开 API 使用本库。

///|
test "conformance: 全部内置语料通过" {
  let failures = @Mr-Houjie/mbt-subtitle.run_conformance()
  for failure in failures {
    println("FAIL \{failure}")
  }
  assert_eq(failures.length(), 0)
  assert_true(@Mr-Houjie/mbt-subtitle.conformance_case_count() >= 15)
}

///|
test "解析与序列化往返" {
  let source = "1\n00:00:01,000 --> 00:00:04,000\n你好\n\n2\n00:00:05,000 --> 00:00:08,000\n世界\n"
  let parsed = match @Mr-Houjie/mbt-subtitle.parse_srt(source) {
    Ok(subtitle) => subtitle
    Err(message) => {
      println("parse error: \{message}")
      @Mr-Houjie/mbt-subtitle.empty_subtitle()
    }
  }
  assert_eq(parsed.cues.length(), 2)
  let output = @Mr-Houjie/mbt-subtitle.serialize_srt(parsed)
  let again = match @Mr-Houjie/mbt-subtitle.parse_srt(output) {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  assert_eq(again.cues.length(), 2)
  assert_eq(again.cues[0].text, "你好")
}

///|
test "平移与缩放" {
  let source = "1\n00:00:01,000 --> 00:00:04,000\nA\n"
  let parsed = match @Mr-Houjie/mbt-subtitle.parse_srt(source) {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  let moved = @Mr-Houjie/mbt-subtitle.shift(parsed, 2000)
  assert_eq(moved.cues[0].start_ms, 3000)
  assert_eq(moved.cues[0].end_ms, 6000)
  let scaled = @Mr-Houjie/mbt-subtitle.scale(parsed, 50)
  assert_eq(scaled.cues[0].start_ms, 500)
  assert_eq(scaled.cues[0].end_ms, 2000)
}

///|
test "校验问题名称" {
  let source = "1\n00:00:01,000 --> 00:00:05,000\nA\n\n2\n00:00:04,000 --> 00:00:08,000\nB\n"
  let parsed = match @Mr-Houjie/mbt-subtitle.parse_srt(source) {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  let issues = @Mr-Houjie/mbt-subtitle.validate(
    parsed,
    @Mr-Houjie/mbt-subtitle.ValidateOptions::new(),
  )
  let mut found = false
  for issue in issues {
    if @Mr-Houjie/mbt-subtitle.issue_kind_name(issue.kind) == "overlap" {
      found = true
    }
  }
  assert_true(found)
}

///|
test "任意文本输入不 panic（固定种子 fuzz）" {
  let mut state = 20261020
  let mut round = 0
  while round < 300 {
    state = state * 48271 % 2147483647
    let length = state % 80
    let builder = StringBuilder()
    let mut i = 0
    while i < length {
      state = state * 48271 % 2147483647
      let code = state % 6
      builder.write_char(
        match code {
          0 => '1'
          1 => '\n'
          2 => ':'
          3 => ','
          4 => '-'
          _ => 'A'
        },
      )
      i = i + 1
    }
    let text = builder.to_string()
    let _ = @Mr-Houjie/mbt-subtitle.parse_srt(text)
    let _ = @Mr-Houjie/mbt-subtitle.parse_vtt(text)
    round = round + 1
  }
  assert_true(true)
}

///|
test "VTT 解析与序列化往返" {
  let source = "WEBVTT\n\n1\n00:00:01.000 --> 00:00:04.000\nHello\n\n2\n00:00:05.000 --> 00:00:08.000\nWorld\n"
  let parsed = match @Mr-Houjie/mbt-subtitle.parse_vtt(source) {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  assert_eq(parsed.cues.length(), 2)
  let output = @Mr-Houjie/mbt-subtitle.serialize_vtt(parsed)
  let again = match @Mr-Houjie/mbt-subtitle.parse_vtt(output) {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  assert_eq(again.cues.length(), 2)
  assert_true(output.has_prefix("WEBVTT\n\n"))
}

///|
test "负向平移钳制到 0" {
  let parsed = match
    @Mr-Houjie/mbt-subtitle.parse_srt("1\n00:00:01,000 --> 00:00:04,000\nA\n") {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  let moved = @Mr-Houjie/mbt-subtitle.shift(parsed, -5000)
  assert_eq(moved.cues[0].start_ms, 0)
  assert_eq(moved.cues[0].end_ms, 0)
}

///|
test "缩放取整" {
  let parsed = match
    @Mr-Houjie/mbt-subtitle.parse_srt("1\n00:00:01,000 --> 00:00:04,000\nA\n") {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  let scaled = @Mr-Houjie/mbt-subtitle.scale(parsed, 150)
  assert_eq(scaled.cues[0].start_ms, 1500)
  assert_eq(scaled.cues[0].end_ms, 6000)
}

///|
test "多类校验问题" {
  let source = "1\n00:00:01,000 --> 00:00:01,200\n\n2\n00:00:02,000 --> 00:00:03,000\n\{long_text()}\n"
  let parsed = match @Mr-Houjie/mbt-subtitle.parse_srt(source) {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  let issues = @Mr-Houjie/mbt-subtitle.validate(
    parsed,
    @Mr-Houjie/mbt-subtitle.ValidateOptions::new(),
  )
  let mut empty = false
  let mut short = false
  let mut long = false
  for issue in issues {
    let kind = @Mr-Houjie/mbt-subtitle.issue_kind_name(issue.kind)
    if kind == "empty-text" {
      empty = true
    }
    if kind == "too-short" {
      short = true
    }
    if kind == "line-too-long" {
      long = true
    }
  }
  assert_true(empty)
  assert_true(short)
  assert_true(long)
}

///|
test "VTT NOTE 块跳过" {
  let source = "WEBVTT\n\nNOTE this is a comment\n\n1\n00:00:01.000 --> 00:00:04.000\nHello\n"
  let parsed = match @Mr-Houjie/mbt-subtitle.parse_vtt(source) {
    Ok(subtitle) => subtitle
    Err(_) => @Mr-Houjie/mbt-subtitle.empty_subtitle()
  }
  assert_eq(parsed.cues.length(), 1)
  assert_eq(parsed.cues[0].text, "Hello")
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
