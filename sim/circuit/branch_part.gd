class_name BranchPart
extends CircuitPart

## 갈림길. 조건을 판정해 신호를 한쪽으로만 보낸다.
##
## 참이면 A 출구, 거짓이면 B 출구. **거짓일 때 A 쪽으로는 아무것도 나가지
## 않는다.** 그래서 A 쪽에 이어진 것은 실행되지 않는다.
##
## 값은 바꾸지 않는다. 어느 쪽으로 보낼지만 정한다. 그래야 갈림길을 이어
## 사슬을 만들 수 있다.
##
## AND 와 OR 는 따로 만든 부품이 아니다. 입력 두 개를 물리고 판정 방식을
## 고르면 된다. 배선으로 발명하는 것이다.

## A 출구. 조건이 참일 때 신호가 나간다.
const PORT_TRUE := 0

## B 출구. 조건이 거짓일 때 신호가 나간다.
const PORT_FALSE := 1

const MODE_TRUTH := 0
const MODE_GREATER_EQUAL := 1
const MODE_LESS := 2
const MODE_EQUAL := 3
const MODE_AND := 4
const MODE_OR := 5
const MODE_COUNT := 6

var mode: int = MODE_TRUTH

## 견줄 수. 실수와도 견줄 수 있도록 눈금을 곱해 쓴다.
var threshold: int = 0

var _false_output: SignalValue = SignalValue.none()
var _next_false_output: SignalValue = SignalValue.none()


static func create(at: Vector3i) -> BranchPart:
    var part := BranchPart.new()
    part.position = at
    return part


static func is_mode(value: int) -> bool:
    return value >= 0 and value < MODE_COUNT


func kind() -> int:
    return BlockType.BRANCH


func output_count() -> int:
    return 2


func output_at(port: int) -> SignalValue:
    if port == PORT_FALSE:
        return _false_output
    return output


func parameters() -> PackedInt32Array:
    return PackedInt32Array([mode, threshold])


func configure(values: PackedInt32Array) -> void:
    if values.size() >= 1 and is_mode(values[0]):
        mode = values[0]
    if values.size() >= 2:
        threshold = values[1]


func extra_hash_fields() -> Array:
    return [["false_output", _false_output.to_key()]]


func commit() -> void:
    output = _next_output
    _false_output = _next_false_output


func compute(_state: WorldState, incoming: Array) -> void:
    _next_output = SignalValue.none()
    _next_false_output = SignalValue.none()

    var carried := _first_present(incoming)
    if carried == null:
        return

    if _decide(incoming, carried):
        _next_output = carried
        return
    _next_false_output = carried


func _decide(incoming: Array, carried: SignalValue) -> bool:
    match mode:
        MODE_GREATER_EQUAL:
            return carried.as_real_scaled() >= threshold * SignalValue.REAL_SCALE
        MODE_LESS:
            return carried.as_real_scaled() < threshold * SignalValue.REAL_SCALE
        MODE_EQUAL:
            return carried.as_real_scaled() == threshold * SignalValue.REAL_SCALE
        MODE_AND:
            return _all_true(incoming)
        MODE_OR:
            return _any_true(incoming)
        _:
            return carried.as_bool()


func _all_true(incoming: Array) -> bool:
    for value: SignalValue in incoming:
        if value.is_present() and not value.as_bool():
            return false
    return true


func _any_true(incoming: Array) -> bool:
    for value: SignalValue in incoming:
        if value.as_bool():
            return true
    return false


func _first_present(incoming: Array) -> SignalValue:
    for value: SignalValue in incoming:
        if value.is_present():
            return value
    return null
