@abstract class_name CircuitPart
extends RefCounted

## 회로 부품 하나.
##
## 부품은 격자 한 칸을 차지한다. 블록으로 놓이고 블록으로 부숴진다.
##
## 신호는 1틱에 한 부품씩 나아간다. 그래서 계산과 반영을 갈라 둔다.
## [method compute] 는 지금 흐르는 신호만 보고 다음 신호를 정하고,
## [method commit] 이 한꺼번에 반영한다. 부수효과는 [method act] 에서 낸다.

var position: Vector3i = Vector3i.ZERO:
    set(value):
        position = value
        if not _anchor_pinned:
            anchor = value

## 세상과 닿는 자리.
##
## 놓인 칸 그대로다.
var anchor: Vector3i = Vector3i.ZERO

## 지금 내보내고 있는 신호. 출구가 하나뿐인 부품은 이것만 쓴다.
var output: SignalValue = SignalValue.none()

var _next_output: SignalValue = SignalValue.none()

var _anchor_pinned: bool = false


## 세상과 닿을 자리를 못박는다.
func pin_anchor(cell: Vector3i) -> void:
    anchor = cell
    _anchor_pinned = true


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


## 놓을 때 정한 설정값. 부품마다 뜻이 다르다.
func parameters() -> PackedInt32Array:
    return PackedInt32Array()


## 설정값을 받아 부품을 맞춘다. 놓을 때 한 번만 부른다.
func configure(_values: PackedInt32Array) -> void:
    pass


## 부품이 스스로 굴리는 상태. 해시에 함께 접힌다.
func extra_hash_fields() -> Array:
    return []


## 출구가 몇 개인가. 갈림길만 둘이다.
func output_count() -> int:
    return 1


## [param port] 번 출구로 나가는 신호. 없는 출구는 신호가 없다.
func output_at(port: int) -> SignalValue:
    if port == 0:
        return output
    return SignalValue.none()


## 부쉈을 때 재료가 돌아오는가. 타 버린 부품은 돌아오지 않는다.
func yields_material() -> bool:
    return true


func to_hash_fields() -> Array:
    var key := "part.%d.%d.%d" % [position.x, position.y, position.z]
    var fields: Array = [
        [key + ".kind", kind()],
        [key + ".output", output.to_key()],
    ]

    var values := parameters()
    for i in values.size():
        fields.append(["%s.param.%d" % [key, i], values[i]])

    for field: Array in extra_hash_fields():
        fields.append(["%s.%s" % [key, field[0]], field[1]])
    return fields
