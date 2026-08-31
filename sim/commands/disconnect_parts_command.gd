class_name DisconnectPartsCommand
extends SimCommand

## 부품 둘 사이의 배선을 걷어낸다.

const TYPE := &"disconnect_parts"

var from: Vector3i = Vector3i.ZERO
var to: Vector3i = Vector3i.ZERO


static func create(p_from: Vector3i, p_to: Vector3i) -> DisconnectPartsCommand:
    var command := DisconnectPartsCommand.new()
    command.from = p_from
    command.to = p_to
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    state.circuit.unlink(from, to)


func write_payload(data: Dictionary) -> void:
    data["from"] = [from.x, from.y, from.z]
    data["to"] = [to.x, to.y, to.z]


func read_payload(data: Dictionary) -> void:
    var raw_from: Array = data.get("from", [0, 0, 0])
    var raw_to: Array = data.get("to", [0, 0, 0])
    from = Vector3i(int(raw_from[0]), int(raw_from[1]), int(raw_from[2]))
    to = Vector3i(int(raw_to[0]), int(raw_to[1]), int(raw_to[2]))
