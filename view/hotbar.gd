class_name Hotbar
extends CanvasLayer

## 손에 든 것을 화면 아래에 보여준다.
##
## 인벤토리와 입력을 읽기만 한다. 여기서 개수를 고치지 않는다.
## 이름은 게임 말로만 적는다. 프로그래밍 용어는 화면에 나오지 않는다.
##
## 한 칸에 누를 숫자 · 이름 · 개수를 함께 적는다. 고른 칸은 밝고 크게,
## 나머지는 흐리게 보인다.

const SLOT_SIZE := Vector2(92, 58)
const SLOT_GAP := 6.0
const BOTTOM_MARGIN := 20.0

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
var _row: HBoxContainer
var _panels: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _selected_slot: int = 0


## 화면에 보일 이름.
static func name_of(block_type: int) -> String:
    return PartWords.name_of(block_type)


func _ready() -> void:
    var anchor := Control.new()
    anchor.name = "Anchor"
    anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(anchor)

    _row = HBoxContainer.new()
    _row.name = "Slots"
    _row.add_theme_constant_override("separation", int(SLOT_GAP))
    _row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    anchor.add_child(_row)

    for slot in InputController.PLACEABLE.size():
        _add_slot(slot, InputController.PLACEABLE[slot])

    _row.position = Vector2(
        -_row.get_combined_minimum_size().x * 0.5,
        -SLOT_SIZE.y - BOTTOM_MARGIN,
    )


func bind(inventory: Inventory, controller: InputController) -> void:
    _inventory = inventory
    _controller = controller


## 인벤토리와 고른 칸을 읽어 화면을 맞춘다.
func sync() -> void:
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
        _panels[slot].position.y = -CHOSEN_LIFT if is_chosen else 0.0
        _style_of(slot).border_width_bottom = 4 if is_chosen else 0
        _style_of(slot).border_width_top = 4 if is_chosen else 0


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
    panel.custom_minimum_size = SLOT_SIZE
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", TEXT_COLOUR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(label)

    _row.add_child(panel)
    _panels.append(panel)
    _labels.append(label)
