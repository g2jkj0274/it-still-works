class_name DisconnectPartsCommand
extends SimCommand

## 부품 둘 사이의 배선을 걷어낸다.

const TYPE := &"disconnect_parts"

var from: Vector3i = Vector3i.ZERO
var to: Vector3i = Vector3i.ZERO

## 어느 구멍에서 나오는가. 갈림길만 구멍이 둘이다.
var port: int = 0


static func create(p_from: Vector3i, p_to: Vector3i, p_port: int = 0) -> DisconnectPartsCommand:
    var command := DisconnectPartsCommand.new()
    command.from = p_from
    command.to = p_to
    command.port = p_port
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    state.circuit.unlink(from, to, port)


func write_payload(data: Dictionary) -> void:
    data["from"] = [from.x, from.y, from.z]
    data["to"] = [to.x, to.y, to.z]
    data["port"] = port


func read_payload(data: Dictionary) -> void:
    var raw_from: Array = data.get("from", [0, 0, 0])
    var raw_to: Array = data.get("to", [0, 0, 0])
    from = Vector3i(int(raw_from[0]), int(raw_from[1]), int(raw_from[2]))
    to = Vector3i(int(raw_to[0]), int(raw_to[1]), int(raw_to[2]))
    port = int(data.get("port", 0))
