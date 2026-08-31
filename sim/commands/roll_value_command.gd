class_name RollValueCommand
extends SimCommand

## 월드 난수원에서 정수 하나를 뽑아 지정한 키에 넣는다.
##
## 난수를 소비하는 명령이므로 실행 순서가 바뀌면 이후 모든 뽑기가 어긋난다.
## 결정론 회귀 테스트가 그 어긋남을 잡는다.

const TYPE := &"roll_value"

var key: StringName = &""
var min_value: int = 0
var max_value: int = 0


static func create(p_key: StringName, p_min: int, p_max: int) -> RollValueCommand:
    var command := RollValueCommand.new()
    command.key = p_key
    command.min_value = p_min
    command.max_value = p_max
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    state.set_value(key, state.rng.next_range(min_value, max_value))


func write_payload(data: Dictionary) -> void:
    data["key"] = String(key)
    data["min"] = min_value
    data["max"] = max_value


func read_payload(data: Dictionary) -> void:
    key = StringName(data.get("key", ""))
    min_value = int(data.get("min", 0))
    max_value = int(data.get("max", 0))
