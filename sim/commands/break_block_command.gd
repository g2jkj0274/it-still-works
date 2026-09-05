class_name BreakBlockCommand
extends SimCommand

## 블록 하나를 부순다.
##
## 섬의 바닥층은 부술 수 없다. 부술 수 있으면 딛을 곳이 없는 칸이 생겨
## 캐릭터가 갇힌다.
##
## **손이 차 있어도 부수지 못한다.** 부순 것을 받을 자리가 없으면 그대로 둔다.
##
## **안이 빈 궤짝만 걷어낼 수 있다.** 부수면 안의 것이 조용히 사라진다.

const TYPE := &"break_block"

var position: Vector3i = Vector3i.ZERO

## 손에 든 것. 도구가 아니면 맨손이다.
##
## **무엇을 들고 있는지는 자료이고, 그것으로 무엇을 캘 수 있는지는 규칙이다.**
## 자료는 화면이 싣고 규칙은 [ToolRules] 가 갖는다. 화면이 규칙을 다시
## 판단하면 언젠가 시뮬레이션과 어긋난다(§1).
var tool: int = BlockType.EMPTY


static func create(p_position: Vector3i, p_tool: int = BlockType.EMPTY) -> BreakBlockCommand:
    var command := BreakBlockCommand.new()
    command.position = p_position
    command.tool = p_tool
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    if VoxelGrid.is_bedrock(position):
        return
    var broken := state.grid.get_block(position)
    if not BlockType.is_breakable(broken):
        return

    # 맞는 도구가 없으면 부숴지지도 않는다(스펙 §3.6).
    #
    # **손에 있는지도 여기서 본다.** 실려 온 것은 "무엇을 들었다고 하는가"일
    # 뿐이다. 놓기가 재료를 인벤토리에서 빼는 것과 같은 자리다 — 그쪽이
    # 화면의 말을 믿지 않는데 이쪽만 믿으면 규칙이 반쪽이 된다.
    if tool != BlockType.EMPTY and state.inventory.count_of(tool) <= 0:
        return
    if not ToolRules.can_break(tool, broken):
        return

    # 타 버린 부품은 재료가 돌아오지 않는다. 소모된 자원은 돌아오지 않는다.
    var part := state.circuit.part_at(position)
    var gives_material := part == null or part.yields_material()

    # 안이 빈 궤짝만 걷어낼 수 있다. 부수면 안의 것이 조용히 사라지기 때문이다.
    if broken == BlockType.CHEST and not state.chests.is_empty(position):
        return

    # **손이 차 있으면 부수지 못한다.** 부수고 나서 버리면 조용히 사라지고,
    # 땅에 떨어뜨리자니 떨어진 것을 주울 길이 아직 없다. 부수지 않는 쪽이
    # 잃는 것이 없다.
    if gives_material and not _has_room(state, part, broken):
        return

    state.grid.set_block(position, BlockType.EMPTY)
    if gives_material:
        state.inventory.add(BlockType.material_of(broken), 1)

    # 부품을 걷어내면 거기 이어진 배선도 함께 사라진다.
    state.circuit.remove_part(position)
    state.crops.uproot(position)
    state.chests.remove(position)


## 부순 것을 받을 자리가 손에 있는가.
func _has_room(state: WorldState, _part: CircuitPart, broken: int) -> bool:
    return state.inventory.has_room_for(BlockType.material_of(broken))


func write_payload(data: Dictionary) -> void:
    data["pos"] = [position.x, position.y, position.z]
    data["tool"] = tool


func read_payload(data: Dictionary) -> void:
    var raw: Array = data.get("pos", [0, 0, 0])
    position = Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
    tool = int(data.get("tool", BlockType.EMPTY))
