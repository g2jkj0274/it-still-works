class_name AddValueCommand
extends SimCommand

## 지정한 키의 값에 증감을 더한다. 없는 키는 0으로 본다.

const TYPE := &"add_value"

var key: StringName = &""
var delta: int = 0


static func create(p_key: StringName, p_delta: int) -> AddValueCommand:
    var command := AddValueCommand.new()
    command.key = p_key
    command.delta = p_delta
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    state.set_value(key, state.get_value(key) + delta)


func write_payload(data: Dictionary) -> void:
    data["key"] = String(key)
    data["delta"] = delta


func read_payload(data: Dictionary) -> void:
    key = StringName(data.get("key", ""))
    delta = int(data.get("delta", 0))
