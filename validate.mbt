// 字幕校验：时长、空文本、重叠与行宽。

///|
fn longest_line_length(text : String) -> Int {
  let mut longest = 0
  let mut current = 0
  for c in text {
    if c == '\n' {
      if current > longest {
        longest = current
      }
      current = 0
    } else {
      current = current + 1
    }
  }
  if current > longest {
    longest = current
  }
  longest
}

///|
/// 校验字幕，返回问题列表。
pub fn validate(subtitle : Subtitle, options : ValidateOptions) -> Array[Issue] {
  let issues : Array[Issue] = []
  let mut i = 0
  while i < subtitle.cues.length() {
    let cue = subtitle.cues[i]
    if cue.end_ms <= cue.start_ms {
      issues.push({
        kind: EndBeforeStart,
        cue_index: cue.index,
        message: "结束时间不晚于开始时间",
      })
    }
    if cue.text.trim().is_empty() {
      issues.push({
        kind: EmptyText,
        cue_index: cue.index,
        message: "字幕文本为空",
      })
    }
    let duration = cue.end_ms - cue.start_ms
    if duration > 0 && duration < options.min_duration_ms {
      issues.push({
        kind: TooShort,
        cue_index: cue.index,
        message: "时长 \{duration}ms 小于下限 \{options.min_duration_ms}ms",
      })
    }
    if duration > options.max_duration_ms {
      issues.push({
        kind: TooLong,
        cue_index: cue.index,
        message: "时长 \{duration}ms 超过上限 \{options.max_duration_ms}ms",
      })
    }
    let longest = longest_line_length(cue.text)
    if longest > options.max_chars_per_line {
      issues.push({
        kind: LineTooLong,
        cue_index: cue.index,
        message: "单行 \{longest} 字符，超过 \{options.max_chars_per_line}",
      })
    }
    if i + 1 < subtitle.cues.length() {
      let next = subtitle.cues[i + 1]
      if cue.end_ms > next.start_ms {
        issues.push({
          kind: Overlap,
          cue_index: cue.index,
          message: "与下一条字幕重叠 \{cue.end_ms - next.start_ms}ms",
        })
      }
    }
    i = i + 1
  }
  issues
}
