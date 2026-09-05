class_name VitalsBar
extends CanvasLayer

## 체력과 포만도를 보여준다. 지표를 읽기만 한다.
##
## 이름을 적는다. 빨간 막대와 주황 막대만으로는 주황이 배라는 것을 알 길이 없다.
##
## **이름이 막대 왼쪽 밖에 놓여 화면 가장자리에 잘려 있었다.** 판 안에서
## 이름과 막대가 한 줄을 나눠 갖도록 다시 짰다. 빛깔과 치수는 [UiTheme] 이 정한다.

## 낮밤 시계와 같은 너비. 둘이 세로로 붙어 한 덩어리로 읽힌다.
const PANEL_WIDTH := DayClock.PANEL_WIDTH

## 이름이 차지하는 자리. 두 글자가 들어간다.
const LABEL_WIDTH := 34.0

const BAR_HEIGHT := 10.0
const ROW_HEIGHT := 20.0

const LABELS: PackedStringArray = ["체력", "배"]

## 시계 판 바로 아래.
const TOP := UiTheme.GAP_EDGE + 58.0 + UiTheme.GAP_TIGHT

var _vitals: Vitals
var _health_fill: ColorRect
var _fullness_fill: ColorRect


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
    panel.position = Vector2(-PANEL_WIDTH - UiTheme.GAP_EDGE, TOP)
    panel.size = Vector2(PANEL_WIDTH, UiTheme.GAP * 2.0 + ROW_HEIGHT * 2.0)
    anchor.add_child(panel)

    _health_fill = _add_row(panel, 0, UiTheme.HEALTH)
    _fullness_fill = _add_row(panel, 1, UiTheme.FOOD)


func bind(vitals: Vitals) -> void:
    _vitals = vitals


func sync() -> void:
    if _vitals == null:
        return
    _health_fill.size.x = _width_for(_vitals.health, Vitals.MAX_HEALTH)
    _fullness_fill.size.x = _width_for(_vitals.fullness, Vitals.MAX_FULLNESS)


func health_ratio() -> float:
    return _health_fill.size.x / _bar_width()


func fullness_ratio() -> float:
    return _fullness_fill.size.x / _bar_width()


static func _bar_width() -> float:
    return PANEL_WIDTH - UiTheme.GAP_WIDE * 2.0 - LABEL_WIDTH - UiTheme.GAP


func _width_for(value: int, limit: int) -> float:
    return _bar_width() * clampf(float(value) / limit, 0.0, 1.0)


func _add_row(panel: Panel, row: int, colour: Color) -> ColorRect:
    var top := UiTheme.GAP + row * ROW_HEIGHT
    var bar_x := UiTheme.GAP_WIDE + LABEL_WIDTH + UiTheme.GAP
    var bar_y := top + (ROW_HEIGHT - BAR_HEIGHT) * 0.5

    var label := Label.new()
    label.text = LABELS[row] if row < LABELS.size() else ""
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.position = Vector2(UiTheme.GAP_WIDE, top)
    UiTheme.apply(label, UiTheme.TEXT_SMALL, UiTheme.INK_DIM)
    panel.add_child(label)

    var track := ColorRect.new()
    track.color = UiTheme.TRACK
    track.position = Vector2(bar_x, bar_y)
    track.size = Vector2(_bar_width(), BAR_HEIGHT)
    track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(track)

    var fill := ColorRect.new()
    fill.color = colour
    fill.position = Vector2(bar_x, bar_y)
    fill.size = Vector2(_bar_width(), BAR_HEIGHT)
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(fill)
    return fill
