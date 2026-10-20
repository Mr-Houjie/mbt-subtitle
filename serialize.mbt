// SRT / WebVTT 序列化。

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn pad3(n : Int) -> String {
  if n < 10 {
    "00" + n.to_string()
  } else if n < 100 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn format_timestamp(ms : Int, separator : Char) -> String {
  let value = if ms < 0 { 0 } else { ms }
  let hours = value / 3600000
  let minutes = value / 60000 % 60
  let seconds = value / 1000 % 60
  let millis = value % 1000
  let sep = match separator {
    ',' => ","
    _ => "."
  }
  "\{pad2(hours)}:\{pad2(minutes)}:\{pad2(seconds)}\{sep}\{pad3(millis)}"
}

///|
/// 序列化为 SRT。
pub fn serialize_srt(subtitle : Subtitle) -> String {
  let builder = StringBuilder()
  let mut i = 0
  while i < subtitle.cues.length() {
    let cue = subtitle.cues[i]
    builder.write_string(cue.index.to_string())
    builder.write_string("\n")
    builder.write_string(format_timestamp(cue.start_ms, ','))
    builder.write_string(" --> ")
    builder.write_string(format_timestamp(cue.end_ms, ','))
    builder.write_string("\n")
    builder.write_string(cue.text)
    builder.write_string("\n\n")
    i = i + 1
  }
  builder.to_string()
}

///|
/// 序列化为 WebVTT。
pub fn serialize_vtt(subtitle : Subtitle) -> String {
  let builder = StringBuilder()
  builder.write_string("WEBVTT\n\n")
  let mut i = 0
  while i < subtitle.cues.length() {
    let cue = subtitle.cues[i]
    builder.write_string(cue.index.to_string())
    builder.write_string("\n")
    builder.write_string(format_timestamp(cue.start_ms, '.'))
    builder.write_string(" --> ")
    builder.write_string(format_timestamp(cue.end_ms, '.'))
    builder.write_string("\n")
    builder.write_string(cue.text)
    builder.write_string("\n\n")
    i = i + 1
  }
  builder.to_string()
}

///|
/// 按格式序列化。
pub fn serialize_subtitle(
  subtitle : Subtitle,
  format : SubtitleFormat,
) -> String {
  match format {
    Srt => serialize_srt(subtitle)
    Vtt => serialize_vtt(subtitle)
  }
}
