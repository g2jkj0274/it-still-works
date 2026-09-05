class_name DayClock
extends CanvasLayer

## 며칠째인지, 지금이 낮인지 밤인지, 해가 얼마나 기울었는지 보여준다.
##
## 낮밤은 이 게임의 리듬이자 시험 사이클이다(스펙 §3.2). **리듬은 예고될 때만
## 리듬이다.** 언제 밤이 오는지 모르면 "낮에 만들고 밤에 시험받는다"는 구조가
## 사람에게 도달하지 않는다 — 그냥 갑자기 어두워지고 뭔가에 맞는다.
##
## 낮밤은 틱만으로 정해지므로(따로 든 상태가 없다) 여기서도 틱만 읽는다.
## 숫자 시계는 두지 않는다. 띠 위를 해가 지나가는 것으로 보인다.
##
## 빛깔과 치수는 [UiTheme] 에서 가져온다. 여기서 색을 정하지 않는다.

## 오른쪽 위에 놓이는 판의 너비. [VitalsBar] 와 같아야 둘이 한 덩어리로 읽힌다.
const PANEL_WIDTH := 208.0

const BAR_HEIGHT := 8.0

## 지금 자리를 가리키는 표시.
const MARKER_SIZE := Vector2(3, 14)

## 밤이 오기 이만큼 남으면 띠가 물든다. 예고가 없으면 긴장도 없다.
const WARNING_TICKS := 30 * Simulation.TICK_RATE

## 해가 기울 때. 낮의 노랑에서 이쪽으로 물든다.
const DUSK := Color(0.96, 0.62, 0.40)

var _label: Label
var _day_part: ColorRect
var _night_part: ColorRect
var _marker: ColorRect
var _tick: int = 0


func _ready() -> void:
    var anchor := Control.new()
    anchor.name = "Anchor"
    anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(anchor)

    var panel := Panel.new()
    panel.name = "Panel"
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
    panel.position = Vector2(-PANEL_WIDTH - UiTheme.GAP_EDGE, UiTheme.GAP_EDGE)
    panel.size = Vector2(PANEL_WIDTH, 58.0)
    anchor.add_child(panel)

    _label = Label.new()
    _label.name = "Day"
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.position = Vector2(UiTheme.GAP_WIDE, UiTheme.GAP)
    UiTheme.apply(_label, UiTheme.TEXT_TITLE, UiTheme.INK)
    panel.add_child(_label)

    # 띠는 글자 아래에 눕는다. 하루가 왼쪽에서 오른쪽으로 흐른다.
    var track_x := UiTheme.GAP_WIDE
    var track_y := 36.0
    var track_width := PANEL_WIDTH - UiTheme.GAP_WIDE * 2.0
    var day_width := track_width * float(DayCycle.DAY_TICKS) / DayCycle.CYCLE_TICKS

    _day_part = _add_block(panel, Vector2(track_x, track_y),
        Vector2(day_width, BAR_HEIGHT), UiTheme.DAY)
    _night_part = _add_block(panel, Vector2(track_x + day_width, track_y),
        Vector2(track_width - day_width, BAR_HEIGHT), UiTheme.NIGHT)
    _marker = _add_block(panel, Vector2(track_x, track_y - (MARKER_SIZE.y - BAR_HEIGHT) * 0.5),
        MARKER_SIZE, UiTheme.INK)

    apply(0)


## 그 틱의 화면을 맞춘다.
func apply(tick: int) -> void:
    _tick = tick

    var track_width := PANEL_WIDTH - UiTheme.GAP_WIDE * 2.0
    _marker.position.x = UiTheme.GAP_WIDE + track_width * marker_ratio()

    # 해가 기울면 낮 쪽 띠가 물든다. 밤이 온다는 예고다.
    _day_part.color = DUSK if is_dusk(tick) else UiTheme.DAY
    _label.text = text_for(tick)


func text() -> String:
    return _label.text


## 하루의 어디쯤인가. 0 이 새벽, 1 이 하루 끝이다.
##
## 자리에서 되짚지 않고 틱에서 바로 낸다. 판을 다시 짜도 이 값은 흔들리지 않는다.
func marker_ratio() -> float:
    return float(DayCycle.phase_tick(_tick)) / DayCycle.CYCLE_TICKS


## 밤이 곧 오는가. 해가 기우는 동안이다.
static func is_dusk(tick: int) -> bool:
    var phase := DayCycle.phase_tick(tick)
    return phase < DayCycle.DAY_TICKS and phase >= DayCycle.DAY_TICKS - WARNING_TICKS


## 화면에 적을 말. 숫자 시계가 아니라 지금이 어느 참인지를 적는다.
static func text_for(tick: int) -> String:
    var day := DayCycle.day_number(tick)
    if DayCycle.is_night(tick):
        return "%d일째 · 밤" % day
    if is_dusk(tick):
        return "%d일째 · 해가 기운다" % day
    return "%d일째 · 낮" % day


func _add_block(parent: Control, where: Vector2, size: Vector2, colour: Color) -> ColorRect:
    var block := ColorRect.new()
    block.color = colour
    block.position = where
    block.size = size
    block.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(block)
    return block
