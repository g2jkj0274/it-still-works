class_name HelpOverlay
extends CanvasLayer

## 조작 안내. 기본은 숨김이고 H 또는 F1 로 켜고 끈다.
##
## 늘 떠 있으면 화면을 가린다. 필요할 때만 부른다.

const MARGIN := Vector2(16, 16)
const TEXT_COLOUR := Color(0.14, 0.16, 0.20)
const BACKDROP := Color(1.0, 1.0, 1.0, 0.82)

const LINES: PackedStringArray = [
    "움직이기      W A S D",
    "겨냥          마우스",
    "놓기          E",
    "부수기        Q",
    "잇기          R  (부품 둘을 차례로)",
    "설정 바꾸기   T",
    "먹기          F",
    "고르기        1 ~ 0",
    "당기고 밀기   마우스 휠",
    "시점 돌리기   [  ]",
    "이 안내       H",
]

var _panel: PanelContainer


func _ready() -> void:
    var anchor := Control.new()
    anchor.name = "Anchor"
    anchor.set_anchors_preset(Control.PRESET_TOP_LEFT)
    anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(anchor)

    var style := StyleBoxFlat.new()
    style.bg_color = BACKDROP
    style.set_corner_radius_all(6)
    style.set_content_margin_all(12)

    _panel = PanelContainer.new()
    _panel.name = "Panel"
    _panel.position = MARGIN
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_theme_stylebox_override("panel", style)
    anchor.add_child(_panel)

    var label := Label.new()
    label.text = "\n".join(LINES)
    label.add_theme_color_override("font_color", TEXT_COLOUR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(label)

    visible = false


func set_shown(shown: bool) -> void:
    visible = shown


func is_shown() -> bool:
    return visible


func text() -> String:
    return "\n".join(LINES)
