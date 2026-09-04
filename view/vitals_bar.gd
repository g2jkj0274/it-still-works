class_name VitalsBar
extends CanvasLayer

## 체력과 포만도를 화면 위쪽에 보여준다. 지표를 읽기만 한다.
##
## 이름을 적는다. 빨간 막대와 주황 막대만으로는 주황이 배라는 것을 알 길이 없다.

const BAR_SIZE := Vector2(180, 14)
const BAR_GAP := 6.0

## 낮밤 띠가 위를 차지하므로 그 아래에서 시작한다.
const MARGIN := Vector2(16, 56)

const LABELS: PackedStringArray = ["체력", "배"]
const LABEL_COLOUR := Color(0.16, 0.18, 0.22)

const HEALTH_COLOUR := Color(0.86, 0.42, 0.44)
const FULLNESS_COLOUR := Color(0.86, 0.72, 0.38)
const EMPTY_COLOUR := Color(0.25, 0.27, 0.31, 0.65)

var _vitals: Vitals
var _health_fill: ColorRect
var _fullness_fill: ColorRect


func _ready() -> void:
    var anchor := Control.new()
    anchor.name = "Anchor"
    anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(anchor)

    _health_fill = _add_bar(anchor, 0, HEALTH_COLOUR)
    _fullness_fill = _add_bar(anchor, 1, FULLNESS_COLOUR)


func bind(vitals: Vitals) -> void:
    _vitals = vitals


func sync() -> void:
    if _vitals == null:
        return
    _health_fill.size.x = _width_for(_vitals.health, Vitals.MAX_HEALTH)
    _fullness_fill.size.x = _width_for(_vitals.fullness, Vitals.MAX_FULLNESS)


func health_ratio() -> float:
    return _health_fill.size.x / BAR_SIZE.x


func fullness_ratio() -> float:
    return _fullness_fill.size.x / BAR_SIZE.x


func _width_for(value: int, limit: int) -> float:
    return BAR_SIZE.x * clampf(float(value) / limit, 0.0, 1.0)


func _add_bar(anchor: Control, row: int, colour: Color) -> ColorRect:
    var origin := Vector2(
        -BAR_SIZE.x - MARGIN.x,
        MARGIN.y + row * (BAR_SIZE.y + BAR_GAP),
    )

    var back := ColorRect.new()
    back.color = EMPTY_COLOUR
    back.position = origin
    back.size = BAR_SIZE
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    anchor.add_child(back)

    var fill := ColorRect.new()
    fill.color = colour
    fill.position = origin
    fill.size = BAR_SIZE
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    anchor.add_child(fill)

    var label := Label.new()
    label.text = LABELS[row] if row < LABELS.size() else ""
    label.add_theme_color_override("font_color", LABEL_COLOUR)
    label.add_theme_font_size_override("font_size", 12)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.position = origin + Vector2(-38.0, -3.0)
    anchor.add_child(label)
    return fill
