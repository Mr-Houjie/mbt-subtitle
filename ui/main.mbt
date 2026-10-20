// mbt-subtitle 的 Web GUI（Rabbita）。
//
// 设计重点：把「字幕对轴」这件事演出来——时间轴、问题徽标、逐条时长，
// 而不是只显示输入和输出。所有计算仍由核心库完成。

///|
struct Model {
  text : String
} derive(Eq)

///|
enum Msg {
  SetText(String)
  LoadNormal
  LoadOverlap
  ShiftBy(Int)
  ScaleBy(Int)
  FixOverlap
}

///|
const NORMAL : String = "1\n00:00:01,000 --> 00:00:04,000\n你好，MoonBit\n\n2\n00:00:05,000 --> 00:00:08,000\n这是一个字幕工具\n\n3\n00:00:09,000 --> 00:00:12,000\n整体平移与缩放\n"

///|
const OVERLAP : String = "1\n00:00:01,000 --> 00:00:05,000\n第一条字幕\n\n2\n00:00:04,000 --> 00:00:08,000\n第二条与第一条重叠\n\n3\n00:00:06,500 --> 00:00:09,000\n第三条也落入重叠区\n"

///|
fn Model::initial() -> Model {
  { text: OVERLAP, }
}

///|
fn map_subtitle(
  text : String,
  transform : (@core.Subtitle) -> @core.Subtitle,
) -> String {
  match @core.parse_subtitle(text, @core.Srt) {
    Ok(subtitle) => @core.serialize_srt(transform(subtitle))
    Err(_) => text
  }
}

///|
fn update(model : Model, msg : Msg) -> Model {
  match msg {
    SetText(text) => { text, }
    LoadNormal => { text: NORMAL, }
    LoadOverlap => { text: OVERLAP, }
    ShiftBy(delta) =>
      {
        text: map_subtitle(model.text, fn(subtitle) {
          @core.shift(subtitle, delta)
        }),
      }
    ScaleBy(percent) =>
      {
        text: map_subtitle(model.text, fn(subtitle) {
          @core.scale(subtitle, percent)
        }),
      }
    FixOverlap =>
      {
        text: map_subtitle(model.text, fn(subtitle) {
          @core.resolve_overlaps(subtitle, 100)
        }),
      }
  }
}

// ---------------------------------------------------------------------------
// 渲染辅助
// ---------------------------------------------------------------------------

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
fn format_time(ms : Int) -> String {
  let value = if ms < 0 { 0 } else { ms }
  let hours = value / 3600000
  let minutes = value / 60000 % 60
  let seconds = value / 1000 % 60
  let millis = value % 1000
  "\{pad2(hours)}:\{pad2(minutes)}:\{pad2(seconds)},\{pad3(millis)}"
}

///|
fn max_end(subtitle : @core.Subtitle) -> Int {
  let mut end = 0
  for cue in subtitle.cues {
    if cue.end_ms > end {
      end = cue.end_ms
    }
  }
  if end == 0 {
    1
  } else {
    end
  }
}

///|
fn first_line(text : String) -> String {
  let builder = StringBuilder()
  for c in text {
    if c == '\n' {
      break
    }
    builder.write_char(c)
  }
  builder.to_string()
}

///|
fn issues_for_cue(
  issues : Array[@core.Issue],
  index : Int,
) -> Array[@core.Issue] {
  let result : Array[@core.Issue] = []
  for issue in issues {
    if issue.cue_index == index {
      result.push(issue)
    }
  }
  result
}

///|
fn has_kind(issues : Array[@core.Issue], kind : String) -> Bool {
  for issue in issues {
    if @core.issue_kind_name(issue.kind) == kind {
      return true
    }
  }
  false
}

///|
fn timeline_view(
  subtitle : @core.Subtitle,
  issues : Array[@core.Issue],
) -> @html.Html {
  let total = max_end(subtitle)
  let bars : Array[@html.Html] = []
  for cue in subtitle.cues {
    let duration = if cue.end_ms > cue.start_ms {
      cue.end_ms - cue.start_ms
    } else {
      0
    }
    let left = cue.start_ms * 100 / total
    let width = if duration * 100 / total < 1 {
      1
    } else {
      duration * 100 / total
    }
    let overlap = has_kind(issues_for_cue(issues, cue.index), "overlap")
    let class_name = if overlap { "bar overlap" } else { "bar" }
    bars.push(
      @html.div(class=class_name, style=["left: \{left}%; width: \{width}%"], [
        @html.span(class="bar-label", cue.index.to_string()),
      ]),
    )
  }
  @html.div(class="timeline", [
    @html.div(class="timeline-track", bars),
    @html.div(class="timeline-axis", [
      @html.span("0"),
      @html.span(format_time(total)),
    ]),
  ])
}

///|
fn issue_list(issues : Array[@core.Issue]) -> @html.Html {
  if issues.length() == 0 {
    return @html.div(class="ok", "未发现问题，可以直接导出")
  }
  let nodes : Array[@html.Html] = []
  for issue in issues {
    nodes.push(
      @html.div(class="issue", [
        @html.span(class="issue-kind", @core.issue_kind_name(issue.kind)),
        @html.span(class="issue-cue", "cue \{issue.cue_index}"),
        @html.span(class="issue-msg", issue.message),
      ]),
    )
  }
  @html.div(class="issue-list", nodes)
}

///|
fn cue_rows(
  subtitle : @core.Subtitle,
  issues : Array[@core.Issue],
) -> Array[@html.Html] {
  let rows : Array[@html.Html] = []
  for cue in subtitle.cues {
    let duration = cue.end_ms - cue.start_ms
    let cue_issues = issues_for_cue(issues, cue.index)
    let badges : Array[@html.Html] = []
    for issue in cue_issues {
      badges.push(@html.span(class="badge", @core.issue_kind_name(issue.kind)))
    }
    let row_class = if badges.length() > 0 { "cue-row bad" } else { "cue-row" }
    rows.push(
      @html.div(class=row_class, [
        @html.div(class="cue-no", cue.index.to_string()),
        @html.div(
          class="cue-time",
          "\{format_time(cue.start_ms)} → \{format_time(cue.end_ms)}",
        ),
        @html.div(class="cue-dur", "\{duration}ms"),
        @html.div(class="cue-text", first_line(cue.text)),
        @html.div(class="cue-badges", badges),
      ]),
    )
  }
  rows
}

///|
fn stats_row(
  subtitle : @core.Subtitle,
  issues : Array[@core.Issue],
) -> @html.Html {
  let total = max_end(subtitle)
  let issue_class = if issues.length() > 0 { "stat bad" } else { "stat good" }
  @html.div(class="stats-row", [
    @html.span(class="stat", "\{subtitle.cues.length()} 条字幕"),
    @html.span(class="stat", "总时长 \{format_time(total)}"),
    @html.span(class=issue_class, "\{issues.length()} 个问题"),
  ])
}

///|
fn analysis_view(text : String) -> @html.Html {
  match @core.parse_subtitle(text, @core.Srt) {
    Err(message) => @html.div(class="error", "解析失败：\{message}")
    Ok(subtitle) => {
      let issues = @core.validate(subtitle, @core.ValidateOptions::new())
      @html.div(class="analysis", [
        stats_row(subtitle, issues),
        timeline_view(subtitle, issues),
        issue_list(issues),
        @html.div(class="cue-table", [
          @html.div(class="cue-head", [
            @html.div(class="cue-no", "#"),
            @html.div(class="cue-time", "起止时间"),
            @html.div(class="cue-dur", "时长"),
            @html.div(class="cue-text", "文本"),
            @html.div(class="cue-badges", "问题"),
          ]),
          @html.div(class="cue-body", cue_rows(subtitle, issues)),
        ]),
      ])
    }
  }
}

///|
fn output_view(text : String) -> @html.Html {
  match @core.parse_subtitle(text, @core.Srt) {
    Err(_) => @html.div(class="error", "无法导出：SRT 解析失败")
    Ok(subtitle) =>
      @html.textarea(
        class="output",
        rows=10,
        value=@core.serialize_srt(subtitle),
        read_only=true,
        "",
      )
  }
}

///|
fn app() -> @rabbita.Val[@html.Html] {
  let (model, emit) = @rabbita.create_pure_state(Model::initial(), update~)
  model.view(model => {
    @html.div(class="page", [
      @html.div(class="hero", [
        @html.h1("mbt-subtitle"),
        @html.p(
          "字幕对轴工作台：一眼看出重叠与时长问题，整体平移 / 缩放，一键消除重叠。",
        ),
      ]),
      @html.div(class="toolbar", [
        @html.button(on_click=emit(ShiftBy(1000)), "整体 +1s"),
        @html.button(on_click=emit(ShiftBy(-1000)), "整体 -1s"),
        @html.button(on_click=emit(ShiftBy(100)), "微调 +100ms"),
        @html.button(on_click=emit(ShiftBy(-100)), "微调 -100ms"),
        @html.button(on_click=emit(ScaleBy(110)), "拉伸 110%"),
        @html.button(on_click=emit(ScaleBy(90)), "压缩 90%"),
        @html.button(on_click=emit(FixOverlap), "一键消除重叠"),
        @html.button(on_click=emit(LoadNormal), "正常示例"),
        @html.button(on_click=emit(LoadOverlap), "重叠示例"),
      ]),
      @html.div(class="workspace", [
        @html.div(class="pane", [
          @html.div(
            class="pane-title",
            "SRT 输入（可粘贴或直接编辑）",
          ),
          @html.textarea(
            class="editor",
            rows=22,
            value=model.text,
            on_input=fn(text) { emit(SetText(text)) },
            "",
          ),
        ]),
        analysis_view(model.text),
      ]),
      @html.div(class="pane output-pane", [
        @html.div(class="pane-title", "导出 SRT（随操作实时更新）"),
        output_view(model.text),
      ]),
    ])
  })
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
