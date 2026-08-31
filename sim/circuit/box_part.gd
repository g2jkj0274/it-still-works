class_name BoxPart
extends CircuitPart

## 상자. 값 하나를 담는다.
##
## 신호로 넣고 신호로 꺼낸다. 담긴 값은 늘 밖으로 나가고 있으므로 배선을 이으면
## 언제든 읽을 수 있다.
##
## 상자에는 모양이 있다. 네모는 정수, 둥근 것은 실수, 작은 것은 불리언을 담는다.
## 모양에 안 맞는 값도 들어가지만 깎인다. 3.7 을 네모 상자에 넣으면 3 이 되고,
## 그 3 을 다시 둥근 상자에 옮겨도 3.7 은 돌아오지 않는다.
##
## 새 값을 넣으면 이전 값은 사라진다.

const SHAPE_SQUARE := 0
const SHAPE_ROUND := 1
const SHAPE_SMALL := 2
const SHAPE_COUNT := 3

var shape: int = SHAPE_SQUARE

var _held: SignalValue = SignalValue.none()


static func create(at: Vector3i) -> BoxPart:
    var part := BoxPart.new()
    part.position = at
    return part


static func is_shape(value: int) -> bool:
    return value >= 0 and value < SHAPE_COUNT


func kind() -> int:
    return BlockType.BOX


func parameters() -> PackedInt32Array:
    return PackedInt32Array([shape])


func configure(values: PackedInt32Array) -> void:
    if values.size() >= 1 and is_shape(values[0]):
        shape = values[0]


func extra_hash_fields() -> Array:
    return [["held", _held.to_key()]]


func compute(_state: WorldState, incoming: Array) -> void:
    var arriving := _first_present(incoming)
    if arriving != null:
        _held = _shave(arriving)
    _next_output = _held


## 상자 모양에 맞춰 값을 깎는다. 깎인 것은 돌아오지 않는다.
func _shave(value: SignalValue) -> SignalValue:
    match shape:
        SHAPE_ROUND:
            return SignalValue.of_real_scaled(value.as_real_scaled())
        SHAPE_SMALL:
            return SignalValue.of_bool(value.as_bool())
        _:
            return SignalValue.of_int(value.as_int())


## 들어온 신호 중 처음으로 흐르고 있는 것. 거짓도 흐르는 신호다.
func _first_present(incoming: Array) -> SignalValue:
    for value: SignalValue in incoming:
        if value.is_present():
            return value
    return null
