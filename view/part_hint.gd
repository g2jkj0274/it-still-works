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
## 자리와 크기는 화면 크기에서 매번 다시 잰다. 한 번만 재면 창이 자리를 잡기
## 전이라 어긋난다.
##
## **줄바꿈을 켜지 않는다.** 줄바꿈을 켜면 라벨이 "얼마든지 좁아질 수 있다"고
## 답해서 폭이 0 에 가깝게 잡히고, 글자마다 줄이 바뀌어 세로줄이 된다.
## 대신 글자 너비를 직접 재서 칸을 잡고, 화면보다 길면 잘라 낸다.

## 핫바 위로 띄울 높이.
const BOTTOM_MARGIN := 96.0
const SIDE_MARGIN := 12.0

## 글 둘레에 둘 여백.
const PADDING := 8.0

const TEXT_COLOUR := Color(0.16, 0.18, 0.22)
const BACKDROP := Color(1.0, 1.0, 1.0, 0.78)

var _controller: InputController
var _label: Label
var _panel: Panel
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

    _panel = Panel.new()
    _panel.name = "Line"
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_theme_stylebox_override("panel", style)
    _anchor.add_child(_panel)

    _label = Label.new()
    _label.name = "Text"
    # 한 줄로만 쓴다. 줄바꿈도, 넘칠 때 늘어나는 것도 허용하지 않는다.
    _label.autowrap_mode = TextServer.AUTOWRAP_OFF
    _label.clip_text = true
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.add_theme_color_override("font_color", TEXT_COLOUR)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(_label)

    _lay_out()


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


## 가로 한 줄로 놓였는가.
##
## 세로줄로 무너지면 화면을 가린다. 그것을 잡는 것이 이 판정이다.
func is_single_line() -> bool:
    if _label.get_line_count() != 1:
        return false
    # 한 줄이라도 칸이 글자 하나 너비라면 세로줄로 보인다.
    return _panel.size.x > _panel.size.y


func _screen_size() -> Vector2:
    var viewport := get_viewport()
    if viewport == null:
        return Vector2(1152, 648)
    return viewport.get_visible_rect().size


## 글자 너비를 직접 재서 칸을 잡는다.
func _lay_out() -> void:
    var screen := _screen_size()
    var measured := _measure()

    var widest := screen.x - SIDE_MARGIN * 2.0
    var width := minf(measured.x + PADDING * 2.0, widest)
    var height := measured.y + PADDING * 2.0

    _panel.size = Vector2(width, height)
    _panel.position = Vector2((screen.x - width) * 0.5, screen.y - BOTTOM_MARGIN - height)

    _label.position = Vector2(PADDING, PADDING)
    _label.size = Vector2(width - PADDING * 2.0, measured.y)


## 지금 글이 한 줄로 놓였을 때의 크기.
func _measure() -> Vector2:
    var font := _label.get_theme_font("font")
    var font_size := _label.get_theme_font_size("font_size")
    if font == null:
        return Vector2(_label.text.length() * 8.0, 16.0)
    return font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


## 고른 것의 이름과 한 줄 설명. 설정이 있으면 그것도 붙인다.
static func line_for(controller: InputController) -> String:
    if controller.is_choosing():
        return "묶는 중 — 고른 칸 %d, 들어오는 자리 %d, 나가는 자리 %d.  B 로 자리를 정하고 G 로 묶는다" % [
            controller.chosen_cells().size(),
            controller.bundle_entries().size(),
            controller.bundle_exits().size(),
        ]
    if controller.wiring_from_branch():
        return "잇는 중 — %s 쪽으로 나간다.  T 로 바꾸고, 이을 부품에 R" % [
            controller.link_port_name()]

    var block_type := controller.selected_block()
    var line := "%s — %s" % [PartWords.name_of(block_type), PartWords.description_of(block_type)]
    if controller.has_part_setting():
        line += "   [지금: %s]" % controller.part_setting_name()
    return line
