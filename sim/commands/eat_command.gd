class_name EatCommand
extends SimCommand

## 작물을 먹는다. 포만도가 찬다.
##
## 회로가 아니라 사람이 하는 일이므로 명령으로 들어온다.

const TYPE := &"eat"

## 작물 하나가 채우는 포만도. 구운 것은 두 배다.
##
## **구우려면 화로가 있어야 하고 화로는 회로가 돌린다**(스펙 §3.6).
## 밥걱정이 주는 것이 회로를 지은 값이다.
const FULLNESS_PER_CROP := 4
const FULLNESS_PER_COOKED := 8


static func create() -> EatCommand:
    return EatCommand.new()


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    # 구운 것을 먼저 먹는다. 배가 덜 찬 채로 좋은 것을 아껴 두면
    # 사람이 손으로 골라야 하는데, 먹는 것은 고를 일이 아니다.
    if state.inventory.take(BlockType.COOKED_CROP, 1):
        state.vitals.feed(FULLNESS_PER_COOKED)
        return
    if not state.inventory.take(BlockType.CROP, 1):
        return
    state.vitals.feed(FULLNESS_PER_CROP)
