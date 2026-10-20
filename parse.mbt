// SRT / WebVTT 解析。
//
// 解析是纯函数：失败时返回带行号的错误信息，不抛异常。

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
fn lines_of(text : String) -> Array[String] {
  let source = if text.has_prefix("\u{feff}") {
    chars_to_string(text.iter().to_array(), 1, text.length())
  } else {
    text
  }
  let lines : Array[String] = []
  let buffer = StringBuilder()
  for c in source {
    if c == '\n' {
      lines.push(buffer.to_string())
      buffer.reset()
    } else if c != '\r' {
      buffer.write_char(c)
    }
  }
  if !source.has_suffix("\n") {
    lines.push(buffer.to_string())
  }
  lines
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
fn parse_timestamp(raw : String) -> Int? {
  let parts = split_char(raw.trim().to_owned(), ':')
  let count = parts.length()
  if count < 2 || count > 3 {
    return None
  }
  let hours = if count == 3 {
    match parse_uint(parts[0]) {
      Some(value) => value
      None => return None
    }
  } else {
    0
  }
  let minutes_raw = if count == 3 { parts[1] } else { parts[0] }
  let minutes = match parse_uint(minutes_raw) {
    Some(value) => value
    None => return None
  }
  let seconds_raw = if count == 3 { parts[2] } else { parts[1] }
  let comma_parts = split_char(seconds_raw, ',')
  let seconds_text = comma_parts[0]
  let comma_fraction = if comma_parts.length() > 1 {
    comma_parts[1]
  } else {
    ""
  }
  let dot_parts = split_char(seconds_text, '.')
  let seconds = match parse_uint(dot_parts[0]) {
    Some(value) => value
    None => return None
  }
  let fraction = if dot_parts.length() > 1 {
    dot_parts[1]
  } else {
    comma_fraction
  }
  let millis = if !fraction.is_empty() {
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
  Some(((hours * 60 + minutes) * 60 + seconds) * 1000 + millis)
}

///|
fn find_substring(text : String, needle : String) -> Int? {
  let chars = text.iter().to_array()
  let pattern = needle.iter().to_array()
  if pattern.length() == 0 || chars.length() < pattern.length() {
    return None
  }
  let mut i = 0
  while i + pattern.length() <= chars.length() {
    let mut j = 0
    let mut matched = true
    while j < pattern.length() {
      if chars[i + j] != pattern[j] {
        matched = false
        break
      }
      j = j + 1
    }
    if matched {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn first_token(text : String) -> String {
  let chars = text.iter().to_array()
  let mut end = chars.length()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == ' ' || chars[i] == '\t' {
      end = i
      break
    }
    i = i + 1
  }
  chars_to_string(chars, 0, end)
}

///|
fn parse_timestamp_line(line : String) -> (Int, Int)? {
  match find_substring(line, "-->") {
    None => None
    Some(position) => {
      let chars = line.iter().to_array()
      let left = chars_to_string(chars, 0, position)
      let right_start = position + 3
      let right = chars_to_string(chars, right_start, chars.length())
      let start = match parse_timestamp(left) {
        Some(value) => value
        None => return None
      }
      let end = match parse_timestamp(first_token(right.trim().to_owned())) {
        Some(value) => value
        None => return None
      }
      Some((start, end))
    }
  }
}

///|
fn is_blank(line : String) -> Bool {
  line.trim().is_empty()
}

///|
fn is_index_line(line : String) -> Bool {
  let text = line.trim()
  if text.is_empty() {
    return false
  }
  for c in text {
    if !c.is_ascii_digit() {
      return false
    }
  }
  true
}

///|
/// 解析时间码（供 CLI 解析 `--by` 等参数）。
pub fn parse_timecode(text : String) -> Int? {
  parse_timestamp(text)
}

///|
/// 解析 SRT。
pub fn parse_srt(text : String) -> Result[Subtitle, String] {
  let lines = lines_of(text)
  let cues : Array[Cue] = []
  let mut i = 0
  while i < lines.length() {
    while i < lines.length() && is_blank(lines[i]) {
      i = i + 1
    }
    if i >= lines.length() {
      break
    }
    let line_number = i + 1
    let mut index = cues.length() + 1
    if is_index_line(lines[i]) {
      match parse_uint(lines[i].trim().to_owned()) {
        Some(value) => index = value
        None => ()
      }
      i = i + 1
    }
    if i >= lines.length() {
      return Err("第 \{line_number} 行：缺少时间轴")
    }
    let timing = match parse_timestamp_line(lines[i]) {
      Some(value) => value
      None =>
        return Err("第 \{i + 1} 行：无法解析时间轴「\{lines[i]}」")
    }
    i = i + 1
    let text_lines : Array[String] = []
    while i < lines.length() && !is_blank(lines[i]) {
      text_lines.push(lines[i])
      i = i + 1
    }
    cues.push({
      index,
      start_ms: timing.0,
      end_ms: timing.1,
      text: join_lines(text_lines),
    })
  }
  if cues.length() == 0 {
    return Err("没有解析到任何字幕")
  }
  Ok({ cues, })
}

///|
fn join_lines(lines : Array[String]) -> String {
  let buffer = StringBuilder()
  let mut i = 0
  while i < lines.length() {
    if i > 0 {
      buffer.write_string("\n")
    }
    buffer.write_string(lines[i])
    i = i + 1
  }
  buffer.to_string()
}

///|
/// 解析 WebVTT。
pub fn parse_vtt(text : String) -> Result[Subtitle, String] {
  let lines = lines_of(text)
  if lines.length() == 0 || !lines[0].trim().has_prefix("WEBVTT") {
    return Err("缺少 WEBVTT 头")
  }
  let cues : Array[Cue] = []
  let mut i = 1
  while i < lines.length() {
    while i < lines.length() && is_blank(lines[i]) {
      i = i + 1
    }
    if i >= lines.length() {
      break
    }
    if lines[i].trim().has_prefix("NOTE") ||
      lines[i].trim().has_prefix("STYLE") ||
      lines[i].trim().has_prefix("REGION") {
      while i < lines.length() && !is_blank(lines[i]) {
        i = i + 1
      }
      continue
    }
    if find_substring(lines[i], "-->") is None {
      if i + 1 < lines.length() &&
        find_substring(lines[i + 1], "-->") is Some(_) {
        i = i + 1
      } else {
        while i < lines.length() && !is_blank(lines[i]) {
          i = i + 1
        }
        continue
      }
    }
    let timing = match parse_timestamp_line(lines[i]) {
      Some(value) => value
      None => return Err("第 \{i + 1} 行：无法解析 VTT 时间轴")
    }
    i = i + 1
    let text_lines : Array[String] = []
    while i < lines.length() && !is_blank(lines[i]) {
      text_lines.push(lines[i])
      i = i + 1
    }
    cues.push({
      index: cues.length() + 1,
      start_ms: timing.0,
      end_ms: timing.1,
      text: join_lines(text_lines),
    })
  }
  if cues.length() == 0 {
    return Err("没有解析到任何字幕")
  }
  Ok({ cues, })
}

///|
/// 按格式解析。
pub fn parse_subtitle(
  text : String,
  format : SubtitleFormat,
) -> Result[Subtitle, String] {
  match format {
    Srt => parse_srt(text)
    Vtt => parse_vtt(text)
  }
}
