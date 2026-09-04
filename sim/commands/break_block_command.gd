class_name BreakBlockCommand
extends SimCommand

## 블록 하나를 부순다.
##
## 섬의 바닥층은 부술 수 없다. 부술 수 있으면 딛을 곳이 없는 칸이 생겨
## 캐릭터가 갇힌다.
##
## **손이 차 있어도 부수지 못한다.** 부순 것을 받을 자리가 없으면 그대로 둔다.

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

    # **손이 차 있으면 부수지 못한다.** 부수고 나서 버리면 조용히 사라지고,
    # 땅에 떨어뜨리자니 떨어진 것을 주울 길이 아직 없다. 부수지 않는 쪽이
    # 잃는 것이 없다.
    if gives_material and not _has_room(state, part, broken):
        return

    state.grid.set_block(position, BlockType.EMPTY)
    if gives_material:
        # 묶음은 종류가 아니라 번호로 돌아온다. 안에 든 것이 저마다 다르다.
        if part is BundlePart:
            state.inventory.add_bundle((part as BundlePart).bundle_id, 1)
        else:
            state.inventory.add(BlockType.material_of(broken), 1)

    # 부품을 걷어내면 거기 이어진 배선도 함께 사라진다.
    state.circuit.remove_part(position)
    state.crops.uproot(position)


## 부순 것을 받을 자리가 손에 있는가.
func _has_room(state: WorldState, part: CircuitPart, broken: int) -> bool:
    if part is BundlePart:
        return state.inventory.has_room_for(
            BlockType.BUNDLE, (part as BundlePart).bundle_id)
    return state.inventory.has_room_for(BlockType.material_of(broken))


func write_payload(data: Dictionary) -> void:
    data["pos"] = [position.x, position.y, position.z]


func read_payload(data: Dictionary) -> void:
    var raw: Array = data.get("pos", [0, 0, 0])
    position = Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
