// 字幕整体变换：平移与缩放。

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn round_div(value : Int, divisor : Int) -> Int {
  if divisor <= 0 {
    return value
  }
  (value + divisor / 2) / divisor
}

///|
/// 整体平移 `delta_ms` 毫秒；结果不会小于 0。
pub fn shift(subtitle : Subtitle, delta_ms : Int) -> Subtitle {
  let cues : Array[Cue] = []
  for cue in subtitle.cues {
    let start = max_int(0, cue.start_ms + delta_ms)
    let end = max_int(start, cue.end_ms + delta_ms)
    cues.push({
      index: cue.index,
      start_ms: start,
      end_ms: end,
      text: cue.text,
    })
  }
  { cues, }
}

///|
/// 按百分比缩放时间轴（100 表示不变）。
pub fn scale(subtitle : Subtitle, percent : Int) -> Subtitle {
  let cues : Array[Cue] = []
  for cue in subtitle.cues {
    let start = round_div(cue.start_ms * percent, 100)
    let end = max_int(start, round_div(cue.end_ms * percent, 100))
    cues.push({
      index: cue.index,
      start_ms: start,
      end_ms: end,
      text: cue.text,
    })
  }
  { cues, }
}

///|
/// 消除重叠：后一条字幕顺延到前一条结束之后 `gap_ms` 毫秒，保持原时长。
pub fn resolve_overlaps(subtitle : Subtitle, gap_ms : Int) -> Subtitle {
  let cues : Array[Cue] = []
  let mut previous_end = -1
  for cue in subtitle.cues {
    let duration = if cue.end_ms > cue.start_ms {
      cue.end_ms - cue.start_ms
    } else {
      0
    }
    let start = if previous_end < 0 || cue.start_ms >= previous_end + gap_ms {
      cue.start_ms
    } else {
      previous_end + gap_ms
    }
    let end = start + duration
    cues.push({
      index: cue.index,
      start_ms: start,
      end_ms: end,
      text: cue.text,
    })
    previous_end = end
  }
  { cues, }
}

///|
/// 重新编号。
pub fn renumber(subtitle : Subtitle) -> Subtitle {
  let cues : Array[Cue] = []
  let mut i = 0
  while i < subtitle.cues.length() {
    let cue = subtitle.cues[i]
    cues.push({
      index: i + 1,
      start_ms: cue.start_ms,
      end_ms: cue.end_ms,
      text: cue.text,
    })
    i = i + 1
  }
  { cues, }
}
