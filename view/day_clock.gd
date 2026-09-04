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

const BAR_SIZE := Vector2(180, 10)
const MARGIN := Vector2(16, 16)

## 지금 자리를 가리키는 표시.
const MARKER_SIZE := Vector2(4, 16)

## 밤이 오기 이만큼 남으면 띠가 물든다. 예고가 없으면 긴장도 없다.
const WARNING_TICKS := 30 * Simulation.TICK_RATE

const DAY_COLOUR := Color(0.98, 0.88, 0.52)
const NIGHT_COLOUR := Color(0.42, 0.46, 0.66)
const DUSK_COLOUR := Color(0.96, 0.66, 0.44)
const MARKER_COLOUR := Color(0.16, 0.18, 0.24)
const TEXT_COLOUR := Color(0.16, 0.18, 0.22)

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

    var origin := Vector2(-BAR_SIZE.x - MARGIN.x, MARGIN.y)
    var day_width := BAR_SIZE.x * float(DayCycle.DAY_TICKS) / DayCycle.CYCLE_TICKS

    _day_part = _add_block(anchor, origin, Vector2(day_width, BAR_SIZE.y), DAY_COLOUR)
    _night_part = _add_block(
        anchor,
        origin + Vector2(day_width, 0.0),
        Vector2(BAR_SIZE.x - day_width, BAR_SIZE.y),
        NIGHT_COLOUR)
    _marker = _add_block(
        anchor, origin, MARKER_SIZE, MARKER_COLOUR)
    _marker.position.y = origin.y - (MARKER_SIZE.y - BAR_SIZE.y) * 0.5

    _label = Label.new()
    _label.name = "Day"
    _label.add_theme_color_override("font_color", TEXT_COLOUR)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.position = origin + Vector2(0.0, BAR_SIZE.y + 4.0)
    anchor.add_child(_label)

    apply(0)


## 그 틱의 화면을 맞춘다.
func apply(tick: int) -> void:
    _tick = tick

    var phase := DayCycle.phase_tick(tick)
    var origin_x := -BAR_SIZE.x - MARGIN.x
    _marker.position.x = origin_x + BAR_SIZE.x * float(phase) / DayCycle.CYCLE_TICKS

    # 해가 기울면 낮 쪽 띠가 물든다. 밤이 온다는 예고다.
    _day_part.color = DUSK_COLOUR if is_dusk(tick) else DAY_COLOUR
    _label.text = text_for(tick)


func text() -> String:
    return _label.text


func marker_ratio() -> float:
    return (_marker.position.x + BAR_SIZE.x + MARGIN.x) / BAR_SIZE.x


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


func _add_block(anchor: Control, where: Vector2, size: Vector2, colour: Color) -> ColorRect:
    var block := ColorRect.new()
    block.color = colour
    block.position = where
    block.size = size
    block.mouse_filter = Control.MOUSE_FILTER_IGNORE
    anchor.add_child(block)
    return block
