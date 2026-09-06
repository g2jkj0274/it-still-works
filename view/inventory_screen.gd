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

## 만들 수 있는 줄과 없는 줄. 흐린 것은 지금 손이 닿지 않는 것이다.
const READY_TINT := Color(1.0, 1.0, 1.0, 1.0)
const OUT_OF_REACH_TINT := Color(1.0, 1.0, 1.0, 0.38)

## 이름표가 마우스에서 얼마나 떨어져 따라오는가.
const HOVER_OFFSET := Vector2(16.0, 14.0)

## 이름표 바탕. 격자 위에 떠도 글자가 읽혀야 한다.
const HOVER_BACKDROP := Color(0.04, 0.05, 0.07, 0.94)

## 무엇을 가리키는가.
const WHERE_HAND := 0
const WHERE_CHEST := 1
const WHERE_CRAFT := 2

signal move_requested(from_where: int, from_slot: int, to_where: int, to_slot: int)

## 반쪽만 옮겨 달라. 우클릭이다.
signal split_requested(from_where: int, from_slot: int, to_where: int, to_slot: int)
## 격자에 놓인 것을 가져가겠다. [param all] 이면 재료가 다할 때까지.
signal craft_requested(all: bool)

## 그 법대로 격자에 재료를 놓아 달라. 만들기 책을 눌렀을 때다.
signal fill_requested(index: int)

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
var _craft_slots: Array[Panel] = []
var _recipe_rows: Array[Panel] = []

## 제작 격자와 결과.
var _craft: Inventory
var _result: Panel
var _craft_title: Label
var _bench_open: bool = false

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

    _craft_title = Label.new()
    _craft_title.name = "CraftTitle"
    _craft_title.text = "만들기"
    _craft_title.add_theme_color_override("font_color", TITLE_COLOUR)
    _craft_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _anchor.add_child(_craft_title)

    for i in Inventory.SLOT_COUNT:
        _hand_slots.append(_make_slot("Hand_%d" % i))
    for i in ChestField.CHEST_SLOTS:
        _chest_slots.append(_make_slot("Chest_%d" % i))
    for i in RecipeBook.GRID_SLOTS:
        _craft_slots.append(_make_slot("Craft_%d" % i))
    _result = _make_slot("Result")
    for i in RecipeBook.count():
        _recipe_rows.append(_make_slot("Recipe_%d" % i))

    visible = false


## 손과 제작 격자를 붙인다. 격자는 시뮬레이션이 들고 있는 것을 읽기만 한다.
func bind(hand: Inventory, craft: Inventory = null) -> void:
    _hand = hand
    _craft = craft


func is_open() -> bool:
    return visible


## 손만 연다. [param at_bench] 이면 격자가 세 칸으로 열린다.
func open(at_bench: bool = false) -> void:
    _chest = null
    _bench_open = at_bench
    _picked = [-1, -1]
    visible = true
    sync()


## 지금 쓸 수 있는 격자 한 변의 칸 수.
func craft_reach() -> int:
    return RecipeBook.GRID_SIZE if _bench_open else RecipeBook.HAND_SIZE


## 그 칸이 지금 쓰이는가. 손일 때는 왼쪽 위 네 칸만 쓴다.
func craft_slot_in_use(slot: int) -> bool:
    var reach := craft_reach()
    return (slot % RecipeBook.GRID_SIZE) < reach and (slot / RecipeBook.GRID_SIZE) < reach


## 지금 격자에 놓인 것으로 만들어지는 것. 없으면 [constant BlockType.EMPTY].
func result_block() -> int:
    if _craft == null:
        return BlockType.EMPTY
    return RecipeBook.output_of(RecipeBook.match_grid(_craft, craft_reach()))


## 궤짝과 함께 연다.
func open_chest(cell: Vector3i, inside: Inventory) -> void:
    _chest_cell = cell
    _chest = inside
    _bench_open = false
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

    # **궤짝을 열면 제작 격자는 물러난다.** 궤짝이 위를 차지해서 격자를 둘
    # 자리가 남지 않고, 마인크래프트의 궤짝 화면에도 격자가 없다.
    var making := not showing_chest()
    _craft_title.visible = making
    _craft_title.text = "만들기 — 작업대" if _bench_open else "만들기"
    for i in _craft_slots.size():
        _craft_slots[i].visible = making and craft_slot_in_use(i)
        if _craft_slots[i].visible and _craft != null:
            _paint(_craft_slots[i], _craft, i, WHERE_CRAFT)
    _result.visible = making
    if making:
        _paint_result()


## 결과 칸. 격자에 놓인 것이 무엇이 되는지 보여준다.
##
## **비어 있어도 칸은 그대로 있다.** 재료를 놓다 말면 결과 칸이 사라졌다가
## 나타나서, 무엇을 보고 있었는지 눈이 다시 찾아야 한다.
func _paint_result() -> void:
    var made := result_block()
    var style := _result.get_theme_stylebox("panel") as StyleBoxFlat
    style.bg_color = SLOT_EMPTY
    style.border_width_bottom = 3 if made != BlockType.EMPTY else 0
    style.border_width_top = 3 if made != BlockType.EMPTY else 0

    _icon_in(_result).show_block(made)
    var count := RecipeBook.yield_of(RecipeBook.match_grid(_craft, craft_reach()))         if _craft != null else 0
    _label_in(_result).text = str(count) if count > 1 else ""


## 화면의 한 점을 눌렀다. 무엇을 눌렀는지 가려 처리한다.
##
## [param half] 이면 반쪽만 옮긴다. 결과 칸에서는 **만들 수 있는 만큼 다**
## 만든다 — 마인크래프트의 시프트 누르고 가져가기 자리다.
func click_at(point: Vector2, half: bool = false) -> void:
    if not visible:
        return

    # 결과 칸을 누르면 가져간다. 재료를 집어 드는 것이 아니다.
    if _result.visible and _rect_of(_result).has_point(point):
        if result_block() != BlockType.EMPTY:
            craft_requested.emit(half)
        return

    for i in _recipe_rows.size():
        if _rect_of(_recipe_rows[i]).has_point(point):
            fill_requested.emit(i)
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
## 격자에서 집어 들 수 있는가. 궤짝을 열었을 때에는 격자가 없다.
func _slot_at(point: Vector2) -> Array[int]:
    for i in _hand_slots.size():
        if _rect_of(_hand_slots[i]).has_point(point):
            return [WHERE_HAND, i]
    if showing_chest():
        for i in _chest_slots.size():
            if _rect_of(_chest_slots[i]).has_point(point):
                return [WHERE_CHEST, i]
    for i in _craft_slots.size():
        if _craft_slots[i].visible and _rect_of(_craft_slots[i]).has_point(point):
            return [WHERE_CRAFT, i]
    return [] as Array[int]


func _amount_in(where: int, slot: int) -> int:
    if where == WHERE_CHEST:
        return _chest.amount_at(slot) if _chest != null else 0
    if where == WHERE_CRAFT:
        return _craft.amount_at(slot) if _craft != null else 0
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

    # **지금 만들 수 있는 것과 없는 것이 똑같이 생겼었다.** 스물넉 줄을 눈으로
    # 훑어도 "뭘 만들 수 있지"를 알 수 없었다. 규칙을 여기 옮겨 적지 않고
    # 제작법에 물어본다.
    panel.modulate = READY_TINT if can_make(index) else OUT_OF_REACH_TINT

    # 넓은 줄이라 그림 옆에 이름과 드는 재료가 함께 들어간다.
    _icon_in(panel).show_block(output)
    _label_in(panel).text = "%s   %s" % [
        PartWords.name_of(output), PartWords.recipe_line(output)]


## 지금 그것을 만들 수 있는가. 재료가 손에 있고, 만드는 자리에 서 있는가.
func can_make(index: int) -> bool:
    if _hand == null:
        return false
    var size := RecipeBook.size_of(index)
    if size.x > craft_reach() or size.y > craft_reach():
        return false
    for entry: Array in RecipeBook.inputs_of(index):
        if _hand.count_of(int(entry[0])) < int(entry[1]):
            return false
    return true


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
    if _result.visible and _rect_of(_result).has_point(point):
        var made := result_block()
        label.text = "%s — 눌러 가져간다 · 시프트로 다 만든다" % PartWords.name_of(made)             if made != BlockType.EMPTY else ""
        return

    for i in _recipe_rows.size():
        if _rect_of(_recipe_rows[i]).has_point(point):
            var output := RecipeBook.output_of(i)
            var where := " · 작업대" if RecipeBook.station_of(i) == RecipeBook.BENCH else ""
            label.text = "%s — %s%s" % [
                PartWords.name_of(output), PartWords.recipe_line(output), where]
            return

    var hit := _slot_at(point)
    if hit.is_empty():
        label.text = ""
        return

    var inventory := _held_in(hit[0])
    if inventory == null or inventory.amount_at(hit[1]) <= 0:
        label.text = ""
        return
    label.text = _name_in(inventory, hit[1])


func _held_in(where: int) -> Inventory:
    if where == WHERE_CHEST:
        return _chest
    if where == WHERE_CRAFT:
        return _craft
    return _hand


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

    _lay_out_craft(left, top, grid_width)

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


## 제작 격자와 결과 칸을 놓는다.
##
## 궤짝을 열지 않았을 때에는 가진 것 위쪽이 비어 있다. 거기에 격자를 둔다 —
## 손이 닿는 자리와 만드는 자리가 가까워야 한 칸씩 옮기는 일이 짧아진다.
func _lay_out_craft(left: float, top: float, grid_width: float) -> void:
    var reach := craft_reach()
    var cell := CELL * 0.86
    var step := cell + GAP
    var craft_left := left + grid_width - step * reach - CELL - PADDING * 2.0
    var craft_top := top - step * reach - PADDING * 2.5
    _craft_title.position = Vector2(craft_left, craft_top - 24.0)

    for i in _craft_slots.size():
        var row := i / RecipeBook.GRID_SIZE
        var col := i % RecipeBook.GRID_SIZE
        _craft_slots[i].position = Vector2(craft_left + col * step, craft_top + row * step)
        _craft_slots[i].size = Vector2(cell, cell)
        _fit_slot(_craft_slots[i])

    # 결과 칸은 격자 오른쪽 한가운데. 마인크래프트가 그 자리에 둔다.
    _result.position = Vector2(
        craft_left + reach * step + PADDING,
        craft_top + (reach * step - CELL) * 0.5)
    _result.size = Vector2(CELL, CELL)
    _fit_slot(_result)


## 칸 하나 안에서 그림과 숫자가 제자리를 잡게 한다.
func _fit_slot(panel: Panel) -> void:
    var icon := _icon_in(panel)
    icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    icon.position = Vector2.ZERO
    icon.size = panel.size

    var label := _label_in(panel)
    label.set_anchors_preset(Control.PRESET_FULL_RECT)
    label.position = Vector2.ZERO
    label.size = panel.size
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


func _place(panel: Panel, left: float, top: float, index: int) -> void:
    panel.position = Vector2(
        left + (index % COLUMNS) * (CELL + GAP),
        top + (index / COLUMNS) * (CELL + GAP))
    panel.size = Vector2(CELL, CELL)
