class_name EatCommand
extends SimCommand

## 작물을 먹는다. 포만도가 찬다.
##
## 회로가 아니라 사람이 하는 일이므로 명령으로 들어온다.

const TYPE := &"eat"

## 작물 하나가 채우는 포만도.
const FULLNESS_PER_CROP := 4


static func create() -> EatCommand:
    return EatCommand.new()


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    if not state.inventory.take(BlockType.CROP, 1):
        return
    state.vitals.feed(FULLNESS_PER_CROP)
