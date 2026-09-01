class_name PartHint
extends CanvasLayer

## 지금 고른 것이 무엇을 하는 물건인지 한 줄로 알려준다.
##
## 조작 안내다. **무엇이 잘못됐는지는 말하지 않는다.** 회로가 왜 안 도는지는
## 만든 사람이 알아내야 할 몫이고, 그것을 알려주는 화면은 만들지 않는다.
##
## 설정이 있는 부품은 지금 고른 설정도 함께 보인다. 놓기 전에 무엇으로 놓는지
## 알 수 있어야 한다.

const BOTTOM_MARGIN := 92.0
const TEXT_COLOUR := Color(0.16, 0.18, 0.22)
const BACKDROP := Color(1.0, 1.0, 1.0, 0.72)

var _controller: InputController
var _label: Label
var _panel: PanelContainer


func _ready() -> void:
    var anchor := Control.new()
    anchor.name = "Anchor"
    anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(anchor)

    var style := StyleBoxFlat.new()
    style.bg_color = BACKDROP
    style.set_corner_radius_all(6)
    style.set_content_margin_all(8)

    _panel = PanelContainer.new()
    _panel.name = "Line"
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_theme_stylebox_override("panel", style)
    anchor.add_child(_panel)

    _label = Label.new()
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.add_theme_color_override("font_color", TEXT_COLOUR)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(_label)


func bind(controller: InputController) -> void:
    _controller = controller


func sync() -> void:
    if _controller == null:
        return
    _label.text = line_for(_controller)
    _panel.position = Vector2(
        -_panel.get_combined_minimum_size().x * 0.5,
        -BOTTOM_MARGIN - _panel.get_combined_minimum_size().y,
    )


func text() -> String:
    return _label.text


## 고른 것의 이름과 한 줄 설명. 설정이 있으면 그것도 붙인다.
static func line_for(controller: InputController) -> String:
    var block_type := controller.selected_block()
    var line := "%s — %s" % [PartWords.name_of(block_type), PartWords.description_of(block_type)]
    if controller.has_part_setting():
        line += "   [%s: %s]" % ["지금", controller.part_setting_name()]
    return line
