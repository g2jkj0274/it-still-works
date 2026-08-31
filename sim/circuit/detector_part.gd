class_name DetectorPart
extends CircuitPart

## 감지기. 무엇을 볼지는 설치할 때 정한다.
##
## 같은 부품인데 지정한 대상에 따라 다르게 동작한다.
##
## **조건을 만족할 때만 신호를 낸다.** 만족하지 않으면 거짓이 아니라 아무것도
## 내지 않는다. 회로에서 "실행된다"는 곧 "신호가 있다"이고, 값은 그 위에 실린다.
##
## 모든 대상이 이제 실제로 동작한다.

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
        TARGET_TIME:
            if DayCycle.is_night(state.tick):
                _next_output = SignalValue.of_bool(true)
        TARGET_THREAT:
            var distance := _nearest_threat_distance(state)
            if distance >= 0:
                _next_output = SignalValue.of_int(distance)
        TARGET_CROP:
            if _ripe_crop_is_near(state):
                _next_output = SignalValue.of_bool(true)
        _:
            pass


## 손 닿는 곳에 다 자란 밭이 있는가.
func _ripe_crop_is_near(state: WorldState) -> bool:
    for cell in state.crops.cells():
        if not state.crops.is_mature(cell):
            continue
        var offset := cell - position
        if offset.x * offset.x + offset.y * offset.y + offset.z * offset.z <= SENSE_RADIUS * SENSE_RADIUS:
            return true
    return false


## 근접한 위협까지의 거리(칸). 아무도 없으면 -1.
##
## 스펙대로 거리를 정수로 내보낸다. 값이 0 일 수 있으므로 신호가 있는지로
## 있고 없음을 가른다.
func _nearest_threat_distance(state: WorldState) -> int:
    var nearest := -1
    for threat in state.threats.threats():
        var offset := threat.position - position
        var squared := offset.x * offset.x + offset.y * offset.y + offset.z * offset.z
        if squared > SENSE_RADIUS * SENSE_RADIUS:
            continue
        var distance := absi(offset.x) + absi(offset.y) + absi(offset.z)
        if nearest < 0 or distance < nearest:
            nearest = distance
    return nearest


func _player_is_near(state: WorldState) -> bool:
    var offset := state.character.cell() - position
    return offset.x * offset.x + offset.y * offset.y + offset.z * offset.z <= SENSE_RADIUS * SENSE_RADIUS
