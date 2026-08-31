class_name ActuatorPart
extends CircuitPart

## 작동기. 붙어 있는 블록을 작동시킨다.
##
## 무엇을 하는지는 붙인 블록이 정하고, 언제 하는지만 회로가 정한다.
## 그래서 나중에 블록을 늘려도 회로 부품은 늘지 않는다.
##
## 지금 작동시킬 수 있는 블록은 문뿐이다. 참이면 열고 거짓이면 닫는다.

var _wants_open: bool = false


static func create(at: Vector3i) -> ActuatorPart:
    var part := ActuatorPart.new()
    part.position = at
    return part


func kind() -> int:
    return BlockType.ACTUATOR


func compute(_state: WorldState, incoming: Array) -> void:
    # 들어온 신호 중 하나라도 참이면 작동한다.
    var active := false
    for value: SignalValue in incoming:
        if value.as_bool():
            active = true
            break

    _wants_open = active
    _next_output = SignalValue.of_bool(active)


func act(state: WorldState) -> void:
    var wanted := BlockType.opened_door() if _wants_open else BlockType.closed_door()
    for offset in VoxelGrid.NEIGHBOURS:
        var neighbour := position + offset
        if not BlockType.is_door(state.grid.get_block(neighbour)):
            continue
        # 닫으려는 자리에 캐릭터가 서 있으면 그대로 둔다. 몸이 블록에 갇히면 안 된다.
        if not _wants_open and state.character.occupies(neighbour):
            continue
        state.grid.set_block(neighbour, wanted)
