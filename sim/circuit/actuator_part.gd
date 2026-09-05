class_name ActuatorPart
extends CircuitPart

## 작동기. 붙어 있는 블록을 작동시킨다.
##
## 무엇을 하는지는 붙인 블록이 정하고, 언제 하는지만 회로가 정한다.
## 그래서 나중에 블록을 늘려도 회로 부품은 늘지 않는다.
##
## 신호가 오면 작동하고 오지 않으면 되돌린다. 회로에서 "실행된다"는 곧
## "신호가 있다"이다. 지금 작동시킬 수 있는 것은 문과 밭과 등이다.
##
## 무엇에 닿는지는 놓인 칸이 아니라 [member CircuitPart.anchor] 에서 잰다.

var _wants_open: bool = false


static func create(at: Vector3i) -> ActuatorPart:
    var part := ActuatorPart.new()
    part.position = at
    return part


func kind() -> int:
    return BlockType.ACTUATOR


func compute(_state: WorldState, incoming: Array) -> void:
    # 신호가 하나라도 닿으면 작동한다.
    var active := false
    for value: SignalValue in incoming:
        if value.is_present():
            active = true
            break

    _wants_open = active
    _next_output = SignalValue.of_bool(active)


func act(state: WorldState) -> void:
    for offset in VoxelGrid.NEIGHBOURS:
        var neighbour := anchor + offset
        _work_door(state, neighbour)
        _work_field(state, neighbour)
        _work_lamp(state, neighbour)
        _work_furnace(state, neighbour)


## 화로는 신호가 닿는 동안 불이 붙고, 붙는 순간 한 번 굽는다.
##
## **손으로는 돌아가지 않는다.** 이것이 이 게임이 마인크래프트와 갈리는
## 자리다(스펙 §3.6). 되풀이 → 작동기 → 화로가 곧 자동 제련소이고,
## 되풀이의 간격이 그대로 제련 속도가 된다.
##
## 무엇을 구울지는 손에 든 것이 정한다. 화로에 넣어 두는 칸은 없다 —
## 넣어 두는 것은 궤짝이다. 구울 수 있는 것이 여럿이면 제작법에 적힌
## 차례가 이긴다. 차례가 고정이므로 언제 돌려도 같은 것이 나온다.
func _work_furnace(state: WorldState, cell: Vector3i) -> void:
    var kind := state.grid.get_block(cell)
    if not BlockType.is_furnace(kind):
        return

    var lit := BlockType.FURNACE_LIT if _wants_open else BlockType.FURNACE
    var was_dark := kind != BlockType.FURNACE_LIT
    state.grid.set_block(cell, lit)

    # 불이 막 붙은 그 틱에만 굽는다. 켜져 있는 내내 구우면 되풀이의 간격이
    # 뜻을 잃고 손에 든 것이 순식간에 사라진다.
    if not _wants_open or not was_dark:
        return
    var index := RecipeBook.first_makeable(state.inventory, RecipeBook.FURNACE)
    if index >= 0:
        RecipeBook.make(state.inventory, index)


## 문은 신호가 오면 열리고 오지 않으면 닫힌다.
func _work_door(state: WorldState, cell: Vector3i) -> void:
    if not BlockType.is_door(state.grid.get_block(cell)):
        return
    # 닫으려는 자리에 캐릭터가 서 있으면 그대로 둔다. 몸이 블록에 갇히면 안 된다.
    if not _wants_open and state.character.occupies(cell):
        return
    var kind := state.grid.get_block(cell)
    state.grid.set_block(cell, BlockType.opened_door(kind) if _wants_open
        else BlockType.closed_door(kind))


## 등은 신호가 오면 켜지고 오지 않으면 꺼진다.
##
## 스펙 §5 의 "자동 조명" — 감지기(시간=밤) → 작동기(등) 이 이것으로 성립한다.
func _work_lamp(state: WorldState, cell: Vector3i) -> void:
    if not BlockType.is_lamp(state.grid.get_block(cell)):
        return
    state.grid.set_block(
        cell, BlockType.lit_lamp() if _wants_open else BlockType.dark_lamp())


## 밭은 신호가 올 때만 거둔다. 다 자라지 않았으면 아무 일도 없다.
func _work_field(state: WorldState, cell: Vector3i) -> void:
    if not _wants_open:
        return
    if state.grid.get_block(cell) != BlockType.FIELD:
        return
    if not state.crops.harvest(cell):
        return
    # 손이 차면 들어가는 만큼만 들어간다. 밭은 이미 거두어졌다.
    state.inventory.add(BlockType.CROP, CropField.YIELD)
