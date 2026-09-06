class_name FillCraftCommand
extends SimCommand

## 만들기 책에서 하나를 골랐다. 그 무늬대로 손에 든 것을 격자에 옮긴다.
##
## **무엇을 만들 수 있는지 몰라 스물넉 줄을 훑던 것**이 이것으로 끝난다.
## 마인크래프트의 만들기 책이 하는 일과 같다 — 모양을 외우지 못해도 만들 수
## 있고, 한 번 놓아 보면 모양이 눈에 남는다.
##
## **한 번에 다 옮긴다.** 칸마다 명령을 하나씩 내면 재료가 도중에 떨어졌을 때
## 반쯤 놓인 격자가 남는다. 놓을 수 있으면 다 놓고, 아니면 아무것도 안 놓는다.
##
## 격자에 이미 놓여 있던 것은 손으로 돌려받는다. 덮어쓰면 물건이 사라진다.

const TYPE := &"fill_craft"

var index: int = -1


static func create(p_index: int) -> FillCraftCommand:
    var command := FillCraftCommand.new()
    command.index = p_index
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    if not RecipeBook.is_index(index):
        return

    # 세 칸짜리는 작업대 곁에서만 놓인다. 화면이 정한 값을 믿지 않는다.
    var reach := CraftCommand.reach_of(state)
    var size := RecipeBook.size_of(index)
    if size.x > reach or size.y > reach:
        return

    _return_everything(state)
    if not _can_afford(state):
        return
    _lay_it_out(state)


## 격자에 놓여 있던 것을 손으로 돌려받는다.
func _return_everything(state: WorldState) -> void:
    for slot in state.craft.slot_count():
        var amount := state.craft.amount_at(slot)
        if amount <= 0:
            continue
        var kind := state.craft.kind_at(slot)
        var left := state.inventory.add(kind, amount, state.craft.variant_at(slot))
        state.craft.take_from_slot(slot, amount - left)


## 무늬에 드는 것이 손에 다 있는가.
func _can_afford(state: WorldState) -> bool:
    for entry: Array in RecipeBook.inputs_of(index):
        if state.inventory.count_of(int(entry[0])) < int(entry[1]):
            return false
    return true


## 무늬대로 한 칸에 하나씩 놓는다.
func _lay_it_out(state: WorldState) -> void:
    for placement: Array in _placements():
        var slot: int = placement[0]
        var kind: int = placement[1]
        if not state.inventory.take(kind, 1):
            continue
        state.craft.put_slot(slot, kind, 1)


## 어느 칸에 무엇을 놓는가. [칸, 종류] 를 차례대로.
##
## 모양이 없는 것은 왼쪽 위부터 채운다. 자리가 뜻을 갖지 않으므로 어디든 된다.
func _placements() -> Array:
    var placed: Array = []
    if RecipeBook.form_of(index) == RecipeBook.SHAPELESS:
        var at := 0
        for kind: int in RecipeBook.pattern_of(index):
            placed.append([_loose_slot(at), kind])
            at += 1
        return placed

    var rows: Array = RecipeBook.pattern_of(index)
    for r in rows.size():
        var row: Array = rows[r]
        for c in row.size():
            var kind := int(row[c])
            if kind != BlockType.EMPTY:
                placed.append([r * RecipeBook.GRID_SIZE + c, kind])
    return placed


## 모양이 없는 것의 몇째 자리. 손이 쓰는 왼쪽 위부터 줄을 채운다.
func _loose_slot(at: int) -> int:
    var wide := RecipeBook.HAND_SIZE
    return (at / wide) * RecipeBook.GRID_SIZE + (at % wide)


func write_payload(data: Dictionary) -> void:
    data["i"] = index


func read_payload(data: Dictionary) -> void:
    index = int(data.get("i", -1))
