@abstract class_name CircuitPart
extends RefCounted

## 회로 부품 하나.
##
## 부품은 격자 한 칸을 차지한다. 블록으로 놓이고 블록으로 부숴진다.
##
## 신호는 1틱에 한 부품씩 나아간다. 그래서 계산과 반영을 갈라 둔다.
## [method compute] 는 지금 흐르는 신호만 보고 다음 신호를 정하고,
## [method commit] 이 한꺼번에 반영한다. 부수효과는 [method act] 에서 낸다.

var position: Vector3i = Vector3i.ZERO

## 지금 내보내고 있는 신호.
var output: SignalValue = SignalValue.none()

var _next_output: SignalValue = SignalValue.none()


## 이 부품이 놓인 블록 종류.
@abstract func kind() -> int


## 들어온 신호를 보고 다음에 내보낼 신호를 정한다. 상태를 바꾸지 않는다.
func compute(_state: WorldState, _incoming: Array) -> void:
    _next_output = SignalValue.none()


## 계산해 둔 신호를 실제로 내보낸다.
func commit() -> void:
    output = _next_output


## 세상을 바꾸는 유일한 지점. 부품 대부분은 아무것도 하지 않는다.
func act(_state: WorldState) -> void:
    pass


## 부품마다 고유한 설정값. 해시와 직렬화에 쓴다.
func parameter() -> int:
    return 0


func to_hash_fields() -> Array:
    var key := "part.%d.%d.%d" % [position.x, position.y, position.z]
    return [
        [key + ".kind", kind()],
        [key + ".parameter", parameter()],
        [key + ".output", output.to_key()],
    ]
