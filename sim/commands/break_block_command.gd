class_name BreakBlockCommand
extends SimCommand

## 블록 하나를 부순다.
##
## 섬의 바닥층은 부술 수 없다. 부술 수 있으면 딛을 곳이 없는 칸이 생겨
## 캐릭터가 갇힌다.

const TYPE := &"break_block"

var position: Vector3i = Vector3i.ZERO


static func create(p_position: Vector3i) -> BreakBlockCommand:
    var command := BreakBlockCommand.new()
    command.position = p_position
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    if VoxelGrid.is_bedrock(position):
        return
    var broken := state.grid.get_block(position)
    if not BlockType.is_breakable(broken):
        return

    # 타 버린 부품은 재료가 돌아오지 않는다. 소모된 자원은 돌아오지 않는다.
    var part := state.circuit.part_at(position)
    var gives_material := part == null or part.yields_material()

    state.grid.set_block(position, BlockType.EMPTY)
    if gives_material:
        state.inventory.add(BlockType.material_of(broken), 1)

    # 부품을 걷어내면 거기 이어진 배선도 함께 사라진다.
    state.circuit.remove_part(position)


func write_payload(data: Dictionary) -> void:
    data["pos"] = [position.x, position.y, position.z]


func read_payload(data: Dictionary) -> void:
    var raw: Array = data.get("pos", [0, 0, 0])
    position = Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
