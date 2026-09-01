class_name PartHint
extends CanvasLayer

## 지금 고른 것이 무엇을 하는 물건인지 한 줄로 알려준다.
##
## 조작 안내다. **무엇이 잘못됐는지는 말하지 않는다.** 회로가 왜 안 도는지는
## 만든 사람이 알아내야 할 몫이고, 그것을 알려주는 화면은 만들지 않는다.
##
## 설정이 있는 부품은 지금 고른 설정도 함께 보인다. 놓기 전에 무엇으로 놓는지
## 알 수 있어야 한다. 배선을 잇는 중이면 어느 출구에서 나가는지도 보인다.
##
## 자리는 화면 크기에서 매번 다시 잰다. 한 번만 재면 창이 자리를 잡기 전이라 어긋난다.

## 핫바 위로 띄울 높이.
const BOTTOM_MARGIN := 96.0
const SIDE_MARGIN := 12.0

const TEXT_COLOUR := Color(0.16, 0.18, 0.22)
const BACKDROP := Color(1.0, 1.0, 1.0, 0.78)

var _controller: InputController
var _label: Label
var _panel: PanelContainer
var _anchor: Control


func _ready() -> void:
    _anchor = Control.new()
    _anchor.name = "Anchor"
    _anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
    _anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_anchor)

    var style := StyleBoxFlat.new()
    style.bg_color = BACKDROP
    style.set_corner_radius_all(6)
    style.set_content_margin_all(8)

    _panel = PanelContainer.new()
    _panel.name = "Line"
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_theme_stylebox_override("panel", style)
    _anchor.add_child(_panel)

    _label = Label.new()
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label.add_theme_color_override("font_color", TEXT_COLOUR)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(_label)


func bind(controller: InputController) -> void:
    _controller = controller


func sync() -> void:
    if _controller == null:
        return
    _label.text = line_for(_controller)
    _lay_out()


func text() -> String:
    return _label.text


## 글이 차지하는 자리.
func panel_rect() -> Rect2:
    return Rect2(_panel.position, _panel.size)


## 글이 통째로 화면 안에 들어와 있는가.
func fully_visible() -> bool:
    return Rect2(Vector2.ZERO, _screen_size()).encloses(panel_rect())


## 고른 것의 이름과 한 줄 설명. 설정이 있으면 그것도 붙인다.
static func line_for(controller: InputController) -> String:
    if controller.wiring_from_branch():
        return "잇는 중 — %s 쪽으로 나간다.  T 로 바꾸고, 이을 부품에 R" % [
            controller.link_port_name()]

    var block_type := controller.selected_block()
    var line := "%s — %s" % [PartWords.name_of(block_type), PartWords.description_of(block_type)]
    if controller.has_part_setting():
        line += "   [지금: %s]" % controller.part_setting_name()
    return line


func _screen_size() -> Vector2:
    var viewport := get_viewport()
    if viewport == null:
        return Vector2(1152, 648)
    return viewport.get_visible_rect().size


func _lay_out() -> void:
    var screen := _screen_size()
    var widest := screen.x - SIDE_MARGIN * 2.0

    _label.custom_minimum_size = Vector2.ZERO
    var wanted := _panel.get_combined_minimum_size()
    var width := minf(wanted.x, widest)
    _panel.size = Vector2(width, wanted.y)
    _panel.position = Vector2(
        (screen.x - width) * 0.5,
        screen.y - BOTTOM_MARGIN - _panel.size.y,
    )
