class_name RepeaterPart
extends CircuitPart

## 되풀이. 받은 신호를 정한 간격으로 반복해 내보낸다.
##
## 횟수를 정하면 그만큼만 돌고 멈춘다.
## 조건을 정하면 조건이 참인 동안 돈다.
## 아무것도 정하지 않으면 끝없이 돈다.
##
## 끝없는 되풀이는 잘못이 아니다. 다만 장치가 과열되어 정지하고, 타 버린 부품은
## 부숴도 재료가 돌아오지 않는다. 파괴적이지 않되 명백한 손해다.
##
## 정해진 만큼만 도는 되풀이는 쉬는 동안 식으므로 타지 않는다.

const MODE_COUNT := 0
const MODE_WHILE := 1
const MODE_FOREVER := 2
const MODE_COUNT_TOTAL := 3

## 이만큼 내보내고 나면 과열된다.
const OVERHEAT_LIMIT := 40

const DEFAULT_INTERVAL := 10
const MIN_INTERVAL := 1

var mode: int = MODE_COUNT
var limit: int = 1
var interval: int = DEFAULT_INTERVAL

## 새 신호를 받을 준비가 되었는가.
## 신호가 참인 채로 머물러 있다고 해서 되풀이가 다시 시작되면 안 된다.
## 한 번 끊겼다 들어와야 새로 시작한다.
var _armed: bool = true

var _running: bool = false
var _remaining: int = 0
var _countdown: int = 0
var _heat: int = 0
var _burnt: bool = false
var _held: SignalValue = SignalValue.none()


static func create(at: Vector3i) -> RepeaterPart:
    var part := RepeaterPart.new()
    part.position = at
    return part


static func is_mode(value: int) -> bool:
    return value >= 0 and value < MODE_COUNT_TOTAL


func kind() -> int:
    return BlockType.REPEATER


func is_burnt() -> bool:
    return _burnt


func yields_material() -> bool:
    return not _burnt


func parameters() -> PackedInt32Array:
    return PackedInt32Array([mode, limit, interval])


func configure(values: PackedInt32Array) -> void:
    if values.size() >= 1 and is_mode(values[0]):
        mode = values[0]
    if values.size() >= 2:
        limit = maxi(values[1], 0)
    if values.size() >= 3:
        interval = maxi(values[2], MIN_INTERVAL)


func extra_hash_fields() -> Array:
    return [
        ["armed", 1 if _armed else 0],
        ["running", 1 if _running else 0],
        ["remaining", _remaining],
        ["countdown", _countdown],
        ["heat", _heat],
        ["burnt", 1 if _burnt else 0],
        ["held", _held.to_key()],
    ]


func compute(_state: WorldState, incoming: Array) -> void:
    _next_output = SignalValue.none()
    if _burnt:
        return

    var trigger := _first_true(incoming)

    if trigger == null:
        # 신호가 끊기면 다시 받을 준비가 된다.
        _armed = true
        if mode == MODE_WHILE:
            _running = false
    elif _armed and not _running:
        _start(trigger)
        _armed = false

    if not _running:
        # 쉬는 동안 식는다. 그래서 정해진 만큼만 도는 되풀이는 타지 않는다.
        _heat = maxi(_heat - 1, 0)
        return

    if _countdown > 0:
        _countdown -= 1
        return

    _next_output = _held
    _countdown = interval
    _heat += 1

    if mode == MODE_COUNT:
        _remaining -= 1
        if _remaining <= 0:
            _running = false

    if _heat >= OVERHEAT_LIMIT:
        _burn()


func _start(trigger: SignalValue) -> void:
    _running = true
    _remaining = limit
    _countdown = 0
    _held = trigger
    if mode == MODE_COUNT and limit <= 0:
        _running = false


## 과열을 부른 그 신호는 이미 나갔다. 멈추는 것은 다음부터다.
func _burn() -> void:
    _burnt = true
    _running = false


## 들어온 신호 중 처음으로 참인 것. 되풀이할 값이 된다.
func _first_true(incoming: Array) -> SignalValue:
    for value: SignalValue in incoming:
        if value.as_bool():
            return value
    return null
