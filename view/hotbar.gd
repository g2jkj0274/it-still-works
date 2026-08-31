class_name Hotbar
extends CanvasLayer

## 손에 든 재료를 화면 아래에 보여준다.
##
## 인벤토리와 입력을 읽기만 한다. 여기서 개수를 고치지 않는다.
## 재료 이름은 게임 말로만 적는다. 프로그래밍 용어는 화면에 나오지 않는다.

const SLOT_SIZE := Vector2(76, 42)
const SLOT_GAP := 8.0
const BOTTOM_MARGIN := 24.0

const CHOSEN_COLOUR := Color(1.0, 1.0, 1.0, 0.92)
const IDLE_COLOUR := Color(1.0, 1.0, 1.0, 0.45)
const TEXT_COLOUR := Color(0.13, 0.16, 0.20)

const _NAMES: Dictionary[int, String] = {
    BlockType.GROUND: "흙",
    BlockType.STONE: "돌",
    BlockType.WOOD: "나무",
    BlockType.DOOR_CLOSED: "문",
    BlockType.DETECTOR: "눈",
    BlockType.ACTUATOR: "손",
    BlockType.REPEATER: "되풀이",
    BlockType.BOX: "상자",
    BlockType.BRANCH: "갈림길",
    BlockType.FIELD: "밭",
    BlockType.CROP: "작물",
}

var _inventory: Inventory
var _controller: InputController
var _row: HBoxContainer
var _panels: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _selected_slot: int = 0


## 화면에 보일 재료 이름.
static func name_of(block_type: int) -> String:
    return _NAMES.get(block_type, "?")


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

    for block_type in InputController.PLACEABLE:
        _add_slot(block_type)

    _row.position = Vector2(
        -(_row.get_combined_minimum_size().x) * 0.5,
        -SLOT_SIZE.y - BOTTOM_MARGIN,
    )


func bind(inventory: Inventory, controller: InputController) -> void:
    _inventory = inventory
    _controller = controller


## 인벤토리와 선택 상태를 읽어 화면을 맞춘다.
func sync() -> void:
    if _inventory == null:
        return

    for slot in InputController.PLACEABLE.size():
        var block_type: int = InputController.PLACEABLE[slot]
        _labels[slot].text = "%s  %d" % [name_of(block_type), _inventory.count_of(block_type)]

    _selected_slot = 0
    if _controller != null:
        var chosen := InputController.PLACEABLE.find(_controller.selected_block())
        if chosen >= 0:
            _selected_slot = chosen

    for slot in _panels.size():
        _panels[slot].modulate = CHOSEN_COLOUR if slot == _selected_slot else IDLE_COLOUR


func slot_count() -> int:
    return _labels.size()


func slot_text(slot: int) -> String:
    if slot < 0 or slot >= _labels.size():
        return ""
    return _labels[slot].text


func selected_slot() -> int:
    return _selected_slot


func _add_slot(block_type: int) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = WorldView.colour_of(block_type)
    style.set_corner_radius_all(6)
    style.set_content_margin_all(8)

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
