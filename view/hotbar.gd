class_name Hotbar
extends CanvasLayer

## 손에 든 것을 화면 아래에 보여준다.
##
## 인벤토리와 입력을 읽기만 한다. 여기서 개수를 고치지 않는다.
## 이름은 게임 말로만 적는다. 프로그래밍 용어는 화면에 나오지 않는다.
##
## 한 칸에 누를 숫자 · 이름 · 개수를 함께 적는다. 고른 칸은 밝고 크게,
## 나머지는 흐리게 보인다.
##
## 자리는 화면 크기에서 매번 다시 잰다. 처음 한 번만 재면 창이 아직 자리를 잡기
## 전이라 어긋나고, 창 크기가 바뀌어도 따라오지 못한다.

const SLOT_HEIGHT := 58.0
const SLOT_WIDTH := 92.0
const SLOT_GAP := 6.0
const BOTTOM_MARGIN := 20.0

## 양옆에 남겨 둘 여백. 좁은 창에서도 칸이 화면 밖으로 나가지 않게 한다.
const SIDE_MARGIN := 12.0

## 고른 칸이 위로 솟는 높이.
const CHOSEN_LIFT := 6.0

const CHOSEN_TINT := Color(1.0, 1.0, 1.0, 1.0)
const IDLE_TINT := Color(1.0, 1.0, 1.0, 0.55)

const TEXT_COLOUR := Color(0.12, 0.14, 0.18)
const EMPTY_TEXT_COLOUR := Color(0.42, 0.44, 0.48)
const CHOSEN_BORDER := Color(0.15, 0.17, 0.22)

## 숫자 키 표시. 열째 칸은 0 이다.
const _KEY_LABELS: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

var _inventory: Inventory
var _controller: InputController
var _anchor: Control
var _panels: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _selected_slot: int = 0
var _slot_width: float = SLOT_WIDTH


## 화면에 보일 이름.
static func name_of(block_type: int) -> String:
    return PartWords.name_of(block_type)


func _ready() -> void:
    _anchor = Control.new()
    _anchor.name = "Anchor"
    _anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
    _anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_anchor)

    for slot in InputController.PLACEABLE.size():
        _add_slot(slot, InputController.PLACEABLE[slot])

    _lay_out()


func bind(inventory: Inventory, controller: InputController) -> void:
    _inventory = inventory
    _controller = controller


## 인벤토리와 고른 칸을 읽어 화면을 맞춘다.
func sync() -> void:
    _lay_out()
    if _inventory == null:
        return

    _selected_slot = 0
    if _controller != null:
        var chosen := InputController.PLACEABLE.find(_controller.selected_block())
        if chosen >= 0:
            _selected_slot = chosen

    for slot in InputController.PLACEABLE.size():
        var block_type: int = InputController.PLACEABLE[slot]
        var held := _inventory.count_of(block_type)

        _labels[slot].text = "%s  %s\n%d" % [_KEY_LABELS[slot], name_of(block_type), held]
        _labels[slot].add_theme_color_override(
            "font_color", TEXT_COLOUR if held > 0 else EMPTY_TEXT_COLOUR)

        var is_chosen := slot == _selected_slot
        _panels[slot].modulate = CHOSEN_TINT if is_chosen else IDLE_TINT
        _style_of(slot).border_width_bottom = 4 if is_chosen else 0
        _style_of(slot).border_width_top = 4 if is_chosen else 0
        _panels[slot].position.y = _row_top() - (CHOSEN_LIFT if is_chosen else 0.0)


func slot_count() -> int:
    return _labels.size()


func slot_text(slot: int) -> String:
    if slot < 0 or slot >= _labels.size():
        return ""
    return _labels[slot].text


func selected_slot() -> int:
    return _selected_slot


## 고른 칸이 눈에 띄게 표시되어 있는가.
func slot_is_marked(slot: int) -> bool:
    if slot < 0 or slot >= _panels.size():
        return false
    return _style_of(slot).border_width_bottom > 0


## 그 칸이 화면에서 차지하는 자리.
func slot_rect(slot: int) -> Rect2:
    if slot < 0 or slot >= _panels.size():
        return Rect2()
    return Rect2(_panels[slot].position, Vector2(_slot_width, SLOT_HEIGHT))


## 열 칸이 모두 화면 안에 들어와 있는가.
func all_slots_visible() -> bool:
    var screen := Rect2(Vector2.ZERO, _screen_size())
    for slot in _panels.size():
        if not screen.encloses(slot_rect(slot)):
            return false
    return true


## 칸 전체가 차지하는 가로 길이.
func row_width() -> float:
    var count := _panels.size()
    if count == 0:
        return 0.0
    return count * _slot_width + (count - 1) * SLOT_GAP


func _screen_size() -> Vector2:
    var viewport := get_viewport()
    if viewport == null:
        return Vector2(1152, 648)
    return viewport.get_visible_rect().size


func _row_top() -> float:
    return _screen_size().y - SLOT_HEIGHT - BOTTOM_MARGIN


## 화면 크기에 맞춰 칸 너비와 자리를 다시 잰다.
##
## 창이 좁으면 칸을 줄여서라도 모두 화면 안에 넣는다. 밖으로 밀려나 보이지 않는
## 칸이 있으면 무엇을 눌러야 하는지 알 수 없다.
func _lay_out() -> void:
    var count := _panels.size()
    if count == 0:
        return

    var available := _screen_size().x - SIDE_MARGIN * 2.0 - (count - 1) * SLOT_GAP
    _slot_width = minf(SLOT_WIDTH, maxf(available / count, 1.0))

    var left := (_screen_size().x - row_width()) * 0.5
    for slot in count:
        _panels[slot].custom_minimum_size = Vector2(_slot_width, SLOT_HEIGHT)
        _panels[slot].size = Vector2(_slot_width, SLOT_HEIGHT)
        _panels[slot].position = Vector2(left + slot * (_slot_width + SLOT_GAP), _row_top())


func _style_of(slot: int) -> StyleBoxFlat:
    return _panels[slot].get_theme_stylebox("panel") as StyleBoxFlat


func _add_slot(slot: int, block_type: int) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Palette.of_block(block_type)
    style.set_corner_radius_all(6)
    style.set_content_margin_all(6)
    style.border_color = CHOSEN_BORDER

    var panel := PanelContainer.new()
    panel.name = "Slot_" + BlockType.name_of(block_type)
    panel.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", TEXT_COLOUR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(label)

    _anchor.add_child(panel)
    _panels.append(panel)
    _labels.append(label)
