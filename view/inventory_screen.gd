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
##
## **칸에는 그림이 든다.** 열한 픽셀 글자로 "되풀이 12" 라고 적힌 칸 서른여섯
## 개는 읽어야만 알 수 있는 표였다. 그림([BlockIcon])과 개수만 두고, 이름은
## 마우스를 얹은 칸 하나만 아래에 뜬다. 마인크래프트가 그렇게 한다.

const COLUMNS := 9
const CELL := 52.0
const GAP := 4.0
const PADDING := 16.0

## 손에 잡히는 줄과 나머지 사이를 벌린다.
const HOTBAR_GAP := 10.0

## 화면 전체를 덮는 그늘. 가방이 열리면 세계가 뒤로 물러난다.
const BACKDROP := Color(0.05, 0.06, 0.08, 0.72)
const PANEL := Color(0.11, 0.12, 0.16, 0.96)
const SLOT_EMPTY := Color(0.16, 0.18, 0.22, 0.9)
const TEXT_COLOUR := UiTheme.INK
const TITLE_COLOUR := UiTheme.INK

## 이름표가 마우스에서 얼마나 떨어져 따라오는가.
const HOVER_OFFSET := Vector2(16.0, 14.0)

## 이름표 바탕. 격자 위에 떠도 글자가 읽혀야 한다.
const HOVER_BACKDROP := Color(0.04, 0.05, 0.07, 0.94)

## 무엇을 가리키는가.
const WHERE_HAND := 0
const WHERE_CHEST := 1

signal move_requested(from_where: int, from_slot: int, to_where: int, to_slot: int)

## 반쪽만 옮겨 달라. 우클릭이다.
signal split_requested(from_where: int, from_slot: int, to_where: int, to_slot: int)
signal craft_requested(index: int)

var _hand: Inventory
var _chest: Inventory
var _chest_cell: Vector3i = Vector3i.ZERO

var _anchor: Control
var _shade: ColorRect
var _title: Label
var _own_title: Label
var _hover_label: Label
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

    # 궤짝을 열면 같은 회색 격자가 둘 뜬다. 어느 것이 내 것인지 이름을 붙인다.
    _own_title = Label.new()
    _own_title.name = "OwnTitle"
    _own_title.text = "가진 것"
    _own_title.add_theme_color_override("font_color", TITLE_COLOUR)
    _own_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _anchor.add_child(_own_title)

    # 마우스를 얹은 칸의 이름. 칸마다 적으면 서른여섯 줄을 읽어야 한다.
    # 마우스를 따라다닌다. 자리를 잡아 두면 화면 아래 한 줄과 겹친다.
    var hover_style := StyleBoxFlat.new()
    hover_style.bg_color = HOVER_BACKDROP
    hover_style.set_corner_radius_all(4)
    hover_style.set_content_margin_all(6)

    _hover_label = Label.new()
    _hover_label.name = "Hovered"
    _hover_label.add_theme_color_override("font_color", TITLE_COLOUR)
    _hover_label.add_theme_stylebox_override("normal", hover_style)
    _hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hover_label.visible = false
    _anchor.add_child(_hover_label)

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
    _own_title.visible = showing_chest()

    for i in _hand_slots.size():
        _paint(_hand_slots[i], _hand, i, WHERE_HAND)
    for i in _chest_slots.size():
        _chest_slots[i].visible = showing_chest()
        if showing_chest():
            _paint(_chest_slots[i], _chest, i, WHERE_CHEST)
    for i in _recipe_rows.size():
        _paint_recipe(_recipe_rows[i], i)


## 화면의 한 점을 눌렀다. 무엇을 눌렀는지 가려 처리한다.
##
## [param half] 이면 반쪽만 옮긴다.
func click_at(point: Vector2, half: bool = false) -> void:
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
        if half:
            split_requested.emit(_picked[0], _picked[1], hit[0], hit[1])
        else:
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

    var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
    style.bg_color = SLOT_EMPTY
    var lifted := _picked[0] == where and _picked[1] == slot
    style.border_width_bottom = 3 if lifted else 0
    style.border_width_top = 3 if lifted else 0

    _icon_in(panel).show_block(kind if amount > 0 else BlockType.EMPTY)
    # 하나뿐인 것에는 숫자를 적지 않는다.
    _label_in(panel).text = str(amount) if amount > 1 else ""


func _paint_recipe(panel: Panel, index: int) -> void:
    var output := RecipeBook.output_of(index)
    var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
    style.bg_color = SLOT_EMPTY
    style.border_width_bottom = 0
    style.border_width_top = 0

    # 넓은 줄이라 그림 옆에 이름과 드는 재료가 함께 들어간다.
    _icon_in(panel).show_block(output)
    _label_in(panel).text = "%s   %s" % [
        PartWords.name_of(output), PartWords.recipe_line(output)]


## 그 칸에 그려진 것. 빈 칸이면 [constant BlockType.EMPTY].
func slot_icon(where: int, slot: int) -> int:
    var panels := _chest_slots if where == WHERE_CHEST else _hand_slots
    if slot < 0 or slot >= panels.size():
        return BlockType.EMPTY
    return _icon_in(panels[slot]).block_type()


## 만들 수 있는 것 한 줄에 그려진 것.
func recipe_icon(index: int) -> int:
    if index < 0 or index >= _recipe_rows.size():
        return BlockType.EMPTY
    return _icon_in(_recipe_rows[index]).block_type()


## 마우스가 얹힌 칸의 이름을 아래에 띄운다. 아무 칸도 아니면 지운다.
func hover_at(point: Vector2) -> void:
    if not visible:
        return
    _name_under(point, _hover_label)
    _hover_label.visible = not _hover_label.text.is_empty()
    if _hover_label.visible:
        _place_hover(point)


## 그 점 아래에 있는 것의 이름을 [param label] 에 적는다. 없으면 지운다.
func _name_under(point: Vector2, label: Label) -> void:
    for i in _recipe_rows.size():
        if _rect_of(_recipe_rows[i]).has_point(point):
            var output := RecipeBook.output_of(i)
            label.text = "%s — %s" % [
                PartWords.name_of(output), PartWords.recipe_line(output)]
            return

    var hit := _slot_at(point)
    if hit.is_empty():
        label.text = ""
        return

    var inventory := _chest if hit[0] == WHERE_CHEST else _hand
    if inventory == null or inventory.amount_at(hit[1]) <= 0:
        label.text = ""
        return
    label.text = _name_in(inventory, hit[1])


## 이름표를 마우스 옆에 놓되 화면 밖으로 나가지 않게 한다.
func _place_hover(point: Vector2) -> void:
    var screen := _screen_size()
    var box := _hover_label.get_minimum_size()
    _hover_label.size = box
    _hover_label.position = Vector2(
        clampf(point.x + HOVER_OFFSET.x, 0.0, maxf(screen.x - box.x, 0.0)),
        clampf(point.y + HOVER_OFFSET.y, 0.0, maxf(screen.y - box.y, 0.0)))


## 마우스가 얹힌 칸의 이름. 아무것도 아니면 빈 글.
func hovered_name() -> String:
    return _hover_label.text if _hover_label != null else ""


func _name_in(inventory: Inventory, slot: int) -> String:
    var kind := inventory.kind_at(slot)
    var name := PartWords.name_of(kind)
    return name


func _icon_in(panel: Panel) -> BlockIcon:
    return panel.get_child(0) as BlockIcon


func _label_in(panel: Panel) -> Label:
    return panel.get_child(1) as Label


func _make_slot(slot_name: String) -> Panel:
    var style := StyleBoxFlat.new()
    style.bg_color = SLOT_EMPTY
    style.set_corner_radius_all(5)
    style.border_color = TEXT_COLOUR

    var panel := Panel.new()
    panel.name = slot_name
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", style)

    # 그림이 먼저 들어가고 개수가 그 위에 얹힌다. 순서가 곧 겹치는 차례다.
    var icon := BlockIcon.new()
    icon.name = "Icon"
    icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.add_child(icon)

    var label := Label.new()
    label.name = "Count"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
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
        _own_title.position = Vector2(left, top - 26.0)
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

    # **줄이 화면 밖으로 넘치면 목록이 아니라 잘린 목록이다.**
    # 제작법이 열다섯이고 앞으로 더 는다. 화면 높이에 맞춰 줄을 눌러 담는다.
    var room := screen.y - UiTheme.GAP_EDGE * 2.0
    var needed := _recipe_rows.size() * row_height
    if needed > room:
        row_height = room / _recipe_rows.size()
    var row_size := Vector2(CELL * 3.4, maxf(row_height - GAP * 0.5, 12.0))
    var recipe_top := (screen.y - _recipe_rows.size() * row_height) * 0.5
    for i in _recipe_rows.size():
        _recipe_rows[i].position = Vector2(recipe_left, recipe_top + i * row_height)
        _recipe_rows[i].size = row_size

        # 넓은 줄에서는 그림이 왼쪽에 서고 글이 그 옆에 눕는다.
        var icon := _icon_in(_recipe_rows[i])
        icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
        icon.position = Vector2(4.0, 0.0)
        icon.size = Vector2(CELL * 0.6, CELL * 0.6)

        var label := _label_in(_recipe_rows[i])
        label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        label.position = Vector2(CELL * 0.6 + 8.0, 0.0)
        label.size = Vector2(CELL * 2.7, CELL * 0.6)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER




func _place(panel: Panel, left: float, top: float, index: int) -> void:
    panel.position = Vector2(
        left + (index % COLUMNS) * (CELL + GAP),
        top + (index / COLUMNS) * (CELL + GAP))
    panel.size = Vector2(CELL, CELL)
