// 公共数据类型。

///|
/// 一条字幕。
pub struct Cue {
  index : Int
  start_ms : Int
  end_ms : Int
  text : String
}

///|
/// 一份字幕文件。
pub struct Subtitle {
  cues : Array[Cue]
}

///|
/// 字幕格式。
pub(all) enum SubtitleFormat {
  Srt
  Vtt
}

///|
/// 校验问题类型。
pub enum IssueKind {
  EndBeforeStart
  EmptyText
  Overlap
  TooShort
  TooLong
  LineTooLong
}

///|
/// 一条校验问题。
pub struct Issue {
  kind : IssueKind
  cue_index : Int
  message : String
}

///|
/// 校验参数。
pub struct ValidateOptions {
  min_duration_ms : Int
  max_duration_ms : Int
  max_chars_per_line : Int
}

///|
pub fn ValidateOptions::new() -> ValidateOptions {
  { min_duration_ms: 500, max_duration_ms: 10000, max_chars_per_line: 42, }
}

///|
pub fn ValidateOptions::create(
  min_duration_ms : Int,
  max_duration_ms : Int,
  max_chars_per_line : Int,
) -> ValidateOptions {
  { min_duration_ms, max_duration_ms, max_chars_per_line, }
}

///|
/// 问题类型名称。
pub fn issue_kind_name(kind : IssueKind) -> String {
  match kind {
    EndBeforeStart => "end-before-start"
    EmptyText => "empty-text"
    Overlap => "overlap"
    TooShort => "too-short"
    TooLong => "too-long"
    LineTooLong => "line-too-long"
  }
}

///|
/// 一条字幕的时长。
pub fn Cue::duration_ms(self : Cue) -> Int {
  self.end_ms - self.start_ms
}

///|
/// 空字幕。
pub fn empty_subtitle() -> Subtitle {
  { cues: [], }
}

///|
/// 字幕条数。
pub fn Subtitle::length(self : Subtitle) -> Int {
  self.cues.length()
}
