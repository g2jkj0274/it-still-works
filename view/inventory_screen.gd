class_name InventoryScreen
extends CanvasLayer

## 인벤토리 화면. 마인크래프트의 그것이다.
##
## 손에 든 것 서른여섯 칸을 펼쳐 보이고, 마우스로 집어 옮긴다. 궤짝을 열면
## 그 안이 위에 함께 뜬다. 옆에는 만들 수 있는 것들이 늘어선다.
##
## **옮기는 것도 명령을 거친다.** 화면이 인벤토리를 직접 고치면 저장한 판을
## 되살렸을 때 물건이 제자리로 돌아간다(CLAUDE.md).
##
## 화면이 열려 있는 동안에는 걷거나 놓거나 부수지 않는다. 마우스가 여기
## 매여 있는데 그대로 겨냥이 되면 엉뚱한 곳을 부순다.

const COLUMNS := 9
const CELL := 52.0
const GAP := 4.0
const PADDING := 16.0

## 손에 잡히는 줄과 나머지 사이를 벌린다.
const HOTBAR_GAP := 10.0

const BACKDROP := Color(0.16, 0.17, 0.21, 0.86)
const PANEL := Color(0.93, 0.93, 0.91, 0.96)
const SLOT_EMPTY := Color(0.80, 0.80, 0.78)
const TEXT_COLOUR := Color(0.14, 0.16, 0.20)
const TITLE_COLOUR := Color(0.96, 0.96, 0.94)

## 무엇을 가리키는가.
const WHERE_HAND := 0
const WHERE_CHEST := 1

signal move_requested(from_where: int, from_slot: int, to_where: int, to_slot: int)
signal craft_requested(index: int)

var _hand: Inventory
var _chest: Inventory
var _chest_cell: Vector3i = Vector3i.ZERO

var _anchor: Control
var _shade: ColorRect
var _title: Label
var _hand_slots: Array[Panel] = []
var _chest_slots: Array[Panel] = []
var _recipe_rows: Array[Panel] = []

## 집어 든 것이 있는 자리. 없으면 [-1, -1].
var _picked: Array[int] = [-1, -1]


func _ready() -> void:
    _anchor = Control.new()
    _anchor.name = "Anchor"
    _anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
    _anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_anchor)

    _shade = ColorRect.new()
    _shade.name = "Shade"
    _shade.color = BACKDROP
    _shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    _shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _anchor.add_child(_shade)

    _title = Label.new()
    _title.name = "Title"
    _title.add_theme_color_override("font_color", TITLE_COLOUR)
    _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _anchor.add_child(_title)

    for i in Inventory.SLOT_COUNT:
        _hand_slots.append(_make_slot("Hand_%d" % i))
    for i in ChestField.CHEST_SLOTS:
        _chest_slots.append(_make_slot("Chest_%d" % i))
    for i in RecipeBook.count():
        _recipe_rows.append(_make_slot("Recipe_%d" % i))

    visible = false


func bind(hand: Inventory) -> void:
    _hand = hand


func is_open() -> bool:
    return visible


## 손만 연다.
func open() -> void:
    _chest = null
    _picked = [-1, -1]
    visible = true
    sync()


## 궤짝과 함께 연다.
func open_chest(cell: Vector3i, inside: Inventory) -> void:
    _chest_cell = cell
    _chest = inside
    _picked = [-1, -1]
    visible = true
    sync()


func close() -> void:
    _picked = [-1, -1]
    visible = false


func chest_cell() -> Vector3i:
    return _chest_cell


func showing_chest() -> bool:
    return _chest != null


## 지금 집어 든 자리. 없으면 [-1, -1].
func picked() -> Array[int]:
    return _picked.duplicate()


func sync() -> void:
    if not visible or _hand == null:
        return

    _lay_out()
    _title.text = "궤짝" if showing_chest() else "가진 것"

    for i in _hand_slots.size():
        _paint(_hand_slots[i], _hand, i, WHERE_HAND)
    for i in _chest_slots.size():
        _chest_slots[i].visible = showing_chest()
        if showing_chest():
            _paint(_chest_slots[i], _chest, i, WHERE_CHEST)
    for i in _recipe_rows.size():
        _paint_recipe(_recipe_rows[i], i)


## 화면의 한 점을 눌렀다. 무엇을 눌렀는지 가려 처리한다.
func click_at(point: Vector2) -> void:
    if not visible:
        return

    for i in _recipe_rows.size():
        if _rect_of(_recipe_rows[i]).has_point(point):
            craft_requested.emit(i)
            return

    var hit := _slot_at(point)
    if hit.is_empty():
        return

    if _picked[0] < 0:
        # 빈 칸을 집어 봐야 소용없다.
        if _amount_in(hit[0], hit[1]) > 0:
            _picked = [hit[0], hit[1]]
        return

    if _picked[0] != hit[0] or _picked[1] != hit[1]:
        move_requested.emit(_picked[0], _picked[1], hit[0], hit[1])
    _picked = [-1, -1]


## 그 점이 어느 칸인가. [어디, 몇째]. 아무 칸도 아니면 빈 배열.
func _slot_at(point: Vector2) -> Array[int]:
    for i in _hand_slots.size():
        if _rect_of(_hand_slots[i]).has_point(point):
            return [WHERE_HAND, i]
    if showing_chest():
        for i in _chest_slots.size():
            if _rect_of(_chest_slots[i]).has_point(point):
                return [WHERE_CHEST, i]
    return [] as Array[int]


func _amount_in(where: int, slot: int) -> int:
    if where == WHERE_CHEST:
        return _chest.amount_at(slot) if _chest != null else 0
    return _hand.amount_at(slot)


func _rect_of(panel: Panel) -> Rect2:
    return Rect2(panel.position, panel.size)


func _paint(panel: Panel, inventory: Inventory, slot: int, where: int) -> void:
    var kind := inventory.kind_at(slot)
    var amount := inventory.amount_at(slot)
    var label := panel.get_child(0) as Label

    var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
    style.bg_color = Palette.of_block(kind) if amount > 0 else SLOT_EMPTY
    var lifted := _picked[0] == where and _picked[1] == slot
    style.border_width_bottom = 3 if lifted else 0
    style.border_width_top = 3 if lifted else 0

    if amount <= 0:
        label.text = ""
        return
    var name := PartWords.name_of(kind)
    if kind == BlockType.BUNDLE:
        name = "%s %s" % [name, PartWords.bundle_name(inventory.variant_at(slot))]
    label.text = "%s\n%d" % [name, amount]


func _paint_recipe(panel: Panel, index: int) -> void:
    var output := RecipeBook.output_of(index)
    var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
    style.bg_color = Palette.of_block(output)
    style.border_width_bottom = 0
    style.border_width_top = 0

    var label := panel.get_child(0) as Label
    label.text = "%s\n%s" % [PartWords.name_of(output), PartWords.recipe_line(output)]


func _make_slot(slot_name: String) -> Panel:
    var style := StyleBoxFlat.new()
    style.bg_color = SLOT_EMPTY
    style.set_corner_radius_all(5)
    style.border_color = TEXT_COLOUR

    var panel := Panel.new()
    panel.name = slot_name
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", TEXT_COLOUR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.add_child(label)

    _anchor.add_child(panel)
    return panel


func _screen_size() -> Vector2:
    var viewport := get_viewport()
    if viewport == null:
        return Vector2(1152, 648)
    return viewport.get_visible_rect().size


## 자리는 화면 크기에서 매번 다시 잰다. 창이 자리를 잡기 전에 한 번만 재면
## 어긋나고, 창 크기가 바뀌어도 따라오지 못한다.
func _lay_out() -> void:
    var screen := _screen_size()
    var grid_width := COLUMNS * CELL + (COLUMNS - 1) * GAP
    var left := (screen.x - grid_width) * 0.5 - 140.0
    var top := screen.y * 0.5 - 40.0

    if showing_chest():
        var chest_rows := ceili(float(_chest_slots.size()) / COLUMNS)
        var chest_top := top - chest_rows * (CELL + GAP) - PADDING * 2.0
        for i in _chest_slots.size():
            _place(_chest_slots[i], left, chest_top, i)
        _title.position = Vector2(left, chest_top - 26.0)
    else:
        _title.position = Vector2(left, top - 26.0)

    # 뒷줄 스물일곱 칸, 그 아래에 손에 잡히는 아홉 칸.
    var back := Inventory.SLOT_COUNT - Inventory.HOTBAR_SLOTS
    for i in _hand_slots.size():
        if i < Inventory.HOTBAR_SLOTS:
            var row := ceili(float(back) / COLUMNS)
            _place(_hand_slots[i], left, top + row * (CELL + GAP) + HOTBAR_GAP, i)
        else:
            _place(_hand_slots[i], left, top, i - Inventory.HOTBAR_SLOTS)

    # 만들 것 목록은 늘 같은 자리에 둔다. 궤짝을 열었다고 목록이 움직이면
    # 눈이 다시 찾아야 한다.
    var recipe_left := left + grid_width + PADDING * 2.0
    var row_height := CELL * 0.6 + GAP
    var recipe_top := (screen.y - _recipe_rows.size() * row_height) * 0.5
    for i in _recipe_rows.size():
        _recipe_rows[i].position = Vector2(recipe_left, recipe_top + i * row_height)
        _recipe_rows[i].size = Vector2(CELL * 3.4, CELL * 0.6)


func _place(panel: Panel, left: float, top: float, index: int) -> void:
    panel.position = Vector2(
        left + (index % COLUMNS) * (CELL + GAP),
        top + (index / COLUMNS) * (CELL + GAP))
    panel.size = Vector2(CELL, CELL)
