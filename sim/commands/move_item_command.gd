class_name MoveItemCommand
extends SimCommand

## 물건을 이 칸에서 저 칸으로 옮긴다.
##
## 인벤토리 화면에서 집어 옮기는 것도 상태 변경이므로 명령을 거친다.
## 그러지 않으면 저장한 판을 되살렸을 때 물건이 제자리로 돌아가 있다.
##
## 어느 인벤토리인지는 **자리**로 가린다. 손이면 궤짝 자리를 비워 둔다.

const TYPE := &"move_item"

## 궤짝이 아니라 손을 가리키는 자리.
const IN_HAND := Vector3i(-1, -1, -1)

var from_where: Vector3i = IN_HAND
var from_slot: int = 0
var to_where: Vector3i = IN_HAND
var to_slot: int = 0


static func create(
    p_from_where: Vector3i, p_from_slot: int,
    p_to_where: Vector3i, p_to_slot: int
) -> MoveItemCommand:
    var command := MoveItemCommand.new()
    command.from_where = p_from_where
    command.from_slot = p_from_slot
    command.to_where = p_to_where
    command.to_slot = p_to_slot
    return command


## 손 안에서 옮긴다.
static func in_hand(p_from: int, p_to: int) -> MoveItemCommand:
    return create(IN_HAND, p_from, IN_HAND, p_to)


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    var source := _inventory(state, from_where)
    var target := _inventory(state, to_where)
    if source == null or target == null:
        return

    if source == target:
        source.move(from_slot, to_slot)
        return

    var held := source.take_slot(from_slot)
    if int(held[1]) <= 0:
        return

    var left := target.put_slot(to_slot, int(held[0]), int(held[1]), int(held[2]))
    if int(left[1]) > 0:
        # 다 들어가지 않으면 남은 것은 있던 자리로 돌아간다. 사라지지 않는다.
        source.put_slot(from_slot, int(left[0]), int(left[1]), int(left[2]))


func _inventory(state: WorldState, where: Vector3i) -> Inventory:
    if where == IN_HAND:
        return state.inventory
    return state.chests.inside(where)


func write_payload(data: Dictionary) -> void:
    data["fw"] = [from_where.x, from_where.y, from_where.z]
    data["fs"] = from_slot
    data["tw"] = [to_where.x, to_where.y, to_where.z]
    data["ts"] = to_slot


func read_payload(data: Dictionary) -> void:
    var raw_from: Array = data.get("fw", [-1, -1, -1])
    var raw_to: Array = data.get("tw", [-1, -1, -1])
    from_where = Vector3i(int(raw_from[0]), int(raw_from[1]), int(raw_from[2]))
    to_where = Vector3i(int(raw_to[0]), int(raw_to[1]), int(raw_to[2]))
    from_slot = int(data.get("fs", 0))
    to_slot = int(data.get("ts", 0))
