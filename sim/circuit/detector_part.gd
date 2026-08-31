class_name DetectorPart
extends CircuitPart

## 감지기. 무엇을 볼지는 설치할 때 정한다.
##
## 같은 부품인데 지정한 대상에 따라 다르게 동작한다.
##
## 아직 세상에 없는 대상(위협·시간·작물)은 신호를 내지 않는다. 거짓을 내면
## "없다"와 "아직 만들지 않았다"가 구별되지 않는다.

const TARGET_PLAYER := 0
const TARGET_THREAT := 1
const TARGET_TIME := 2
const TARGET_CROP := 3
const TARGET_ITEM := 4
const TARGET_COUNT := 5

## 근접으로 볼 거리(칸).
const SENSE_RADIUS := 3

var target: int = TARGET_PLAYER


static func create(at: Vector3i, watched: int) -> DetectorPart:
    var part := DetectorPart.new()
    part.position = at
    part.target = watched if is_target(watched) else TARGET_PLAYER
    return part


static func is_target(value: int) -> bool:
    return value >= 0 and value < TARGET_COUNT


func kind() -> int:
    return BlockType.DETECTOR


func parameter() -> int:
    return target


func compute(state: WorldState, _incoming: Array) -> void:
    match target:
        TARGET_PLAYER:
            _next_output = SignalValue.of_bool(_player_is_near(state))
        TARGET_ITEM:
            _next_output = SignalValue.of_int(state.inventory.total())
        _:
            # 위협·시간·작물은 아직 세상에 없다.
            _next_output = SignalValue.none()


func _player_is_near(state: WorldState) -> bool:
    var offset := state.character.cell() - position
    return offset.x * offset.x + offset.y * offset.y + offset.z * offset.z <= SENSE_RADIUS * SENSE_RADIUS
