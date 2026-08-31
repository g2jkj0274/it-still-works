class_name DetectorPart
extends CircuitPart

## 감지기. 무엇을 볼지는 설치할 때 정한다.
##
## 같은 부품인데 지정한 대상에 따라 다르게 동작한다.
##
## **조건을 만족할 때만 신호를 낸다.** 만족하지 않으면 거짓이 아니라 아무것도
## 내지 않는다. 회로에서 "실행된다"는 곧 "신호가 있다"이고, 값은 그 위에 실린다.
##
## 아직 세상에 없는 대상(위협·시간·작물)도 신호를 내지 않는다.

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


func parameters() -> PackedInt32Array:
    return PackedInt32Array([target])


func configure(values: PackedInt32Array) -> void:
    if values.size() >= 1 and is_target(values[0]):
        target = values[0]


func compute(state: WorldState, _incoming: Array) -> void:
    _next_output = SignalValue.none()

    match target:
        TARGET_PLAYER:
            if _player_is_near(state):
                _next_output = SignalValue.of_bool(true)
        TARGET_ITEM:
            var held := state.inventory.total()
            if held > 0:
                _next_output = SignalValue.of_int(held)
        _:
            # 위협·시간·작물은 아직 세상에 없다.
            pass


func _player_is_near(state: WorldState) -> bool:
    var offset := state.character.cell() - position
    return offset.x * offset.x + offset.y * offset.y + offset.z * offset.z <= SENSE_RADIUS * SENSE_RADIUS
