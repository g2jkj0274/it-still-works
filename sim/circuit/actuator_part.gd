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


## 문은 신호가 오면 열리고 오지 않으면 닫힌다.
func _work_door(state: WorldState, cell: Vector3i) -> void:
    if not BlockType.is_door(state.grid.get_block(cell)):
        return
    # 닫으려는 자리에 캐릭터가 서 있으면 그대로 둔다. 몸이 블록에 갇히면 안 된다.
    if not _wants_open and state.character.occupies(cell):
        return
    state.grid.set_block(cell, BlockType.opened_door() if _wants_open else BlockType.closed_door())


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
