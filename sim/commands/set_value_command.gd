class_name SetValueCommand
extends SimCommand

## 지정한 키에 값을 그대로 넣는다.

const TYPE := &"set_value"

var key: StringName = &""
var value: int = 0


static func create(p_key: StringName, p_value: int) -> SetValueCommand:
    var command := SetValueCommand.new()
    command.key = p_key
    command.value = p_value
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    state.set_value(key, value)


func write_payload(data: Dictionary) -> void:
    data["key"] = String(key)
    data["value"] = value


func read_payload(data: Dictionary) -> void:
    key = StringName(data.get("key", ""))
    value = int(data.get("value", 0))
