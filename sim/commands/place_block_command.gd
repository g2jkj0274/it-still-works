class_name PlaceBlockCommand
extends SimCommand

## 빈 칸에 블록을 놓는다.
##
## 아무것에도 붙지 않은 칸에는 놓을 수 없다. 한 칸씩 이어 붙이면 다리를 놓을 수
## 있지만 허공에 홀로 뜬 블록은 만들 수 없다.

const TYPE := &"place_block"

var position: Vector3i = Vector3i.ZERO
var block_type: int = BlockType.EMPTY


static func create(p_position: Vector3i, p_block_type: int) -> PlaceBlockCommand:
    var command := PlaceBlockCommand.new()
    command.position = p_position
    command.block_type = p_block_type
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    if not BlockType.is_solid(block_type):
        return
    if not state.grid.is_empty_cell(position):
        return
    if state.character.occupies(position):
        return
    if not _has_solid_neighbour(state.grid):
        return

    # 재료는 마지막에 빼다. 놓이지 않았는데 재료만 사라지면 손해다.
    if not state.inventory.take(block_type, 1):
        return

    state.grid.set_block(position, block_type)
    if block_type == BlockType.FIELD:
        state.crops.plant(position)


func _has_solid_neighbour(grid: VoxelGrid) -> bool:
    for offset in VoxelGrid.NEIGHBOURS:
        if grid.is_solid(position + offset):
            return true
    return false


func write_payload(data: Dictionary) -> void:
    data["pos"] = [position.x, position.y, position.z]
    data["block"] = block_type


func read_payload(data: Dictionary) -> void:
    var raw: Array = data.get("pos", [0, 0, 0])
    position = Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
    block_type = int(data.get("block", BlockType.EMPTY))
