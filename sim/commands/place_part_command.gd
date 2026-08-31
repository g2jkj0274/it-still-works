class_name PlacePartCommand
extends SimCommand

## 회로 부품을 놓는다.
##
## 부품도 블록이라 격자 한 칸을 차지한다. 다만 회로에 등록해야 하므로 지형
## 블록과는 다른 명령을 쓴다.
##
## 감지기가 무엇을 볼지는 놓을 때 정한다. 놓고 나서 바꾸지 못한다.

const TYPE := &"place_part"

var position: Vector3i = Vector3i.ZERO
var part_type: int = BlockType.DETECTOR
var target: int = DetectorPart.TARGET_PLAYER


static func create(p_position: Vector3i, p_part_type: int, p_target: int = DetectorPart.TARGET_PLAYER) -> PlacePartCommand:
    var command := PlacePartCommand.new()
    command.position = p_position
    command.part_type = p_part_type
    command.target = p_target
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    if not BlockType.is_part(part_type):
        return
    if not state.grid.is_empty_cell(position):
        return
    if state.character.occupies(position):
        return
    if not _has_solid_neighbour(state.grid):
        return
    if state.circuit.has_part(position):
        return
    if not state.inventory.take(part_type, 1):
        return

    state.grid.set_block(position, part_type)
    state.circuit.add_part(_make_part())


func _make_part() -> CircuitPart:
    if part_type == BlockType.DETECTOR:
        return DetectorPart.create(position, target)
    return ActuatorPart.create(position)


func _has_solid_neighbour(grid: VoxelGrid) -> bool:
    for offset in VoxelGrid.NEIGHBOURS:
        if grid.is_solid(position + offset):
            return true
    return false


func write_payload(data: Dictionary) -> void:
    data["pos"] = [position.x, position.y, position.z]
    data["part"] = part_type
    data["target"] = target


func read_payload(data: Dictionary) -> void:
    var raw: Array = data.get("pos", [0, 0, 0])
    position = Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
    part_type = int(data.get("part", BlockType.DETECTOR))
    target = int(data.get("target", DetectorPart.TARGET_PLAYER))
