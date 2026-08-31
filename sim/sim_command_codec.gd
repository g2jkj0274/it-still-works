class_name SimCommandCodec
extends RefCounted

## 명령 ↔ 딕셔너리 변환.
##
## 종류 이름으로 구현체를 고른다. 알 수 없는 종류면 null 을 돌려주며,
## 그 처리는 호출자가 정한다. 시뮬레이션은 null 명령을 큐에 넣지 않는다.


static func to_dict(command: SimCommand) -> Dictionary:
    return command.to_dict()


static func from_dict(data: Dictionary) -> SimCommand:
    var command := create_by_type(StringName(data.get("type", "")))
    if command == null:
        return null
    command.tick = int(data.get("tick", 0))
    command.read_payload(data)
    return command


## 종류 이름에 해당하는 빈 명령을 만든다. 없으면 null.
static func create_by_type(type: StringName) -> SimCommand:
    if type == SetValueCommand.TYPE:
        return SetValueCommand.new()
    if type == AddValueCommand.TYPE:
        return AddValueCommand.new()
    if type == RollValueCommand.TYPE:
        return RollValueCommand.new()
    if type == MoveCharacterCommand.TYPE:
        return MoveCharacterCommand.new()
    return null
