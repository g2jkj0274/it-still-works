class_name WorldState
extends RefCounted

## 시뮬레이션이 소유하는 전체 상태.
##
## 노드 트리와 렌더링을 알지 못한다. 헤드리스로 단독 생성·실행된다.
## 표현 레이어는 이 객체를 읽기만 한다.
##
## 값은 정수만 담는다. 시뮬레이션 로직에 부동소수점을 들이지 않기 위한 제약이다.

## 지금까지 처리를 마친 틱 수. 다음에 실행할 틱 번호이기도 하다.
var tick: int = 0

## 이 월드의 유일한 난수원.
var rng: SimRng

var _values: Dictionary[StringName, int] = {}


func _init(p_rng: SimRng = null) -> void:
    rng = p_rng if p_rng != null else SimRng.new(0)


func set_value(key: StringName, value: int) -> void:
    _values[key] = value


func get_value(key: StringName, fallback: int = 0) -> int:
    if not _values.has(key):
        return fallback
    return _values[key]


func has_value(key: StringName) -> bool:
    return _values.has(key)


func erase_value(key: StringName) -> void:
    _values.erase(key)


func value_count() -> int:
    return _values.size()


## 항상 정렬된 키를 돌려준다.
## 딕셔너리 순회 순서는 보장되지 않으므로 시뮬레이션 판단에 직접 쓰지 않는다.
func sorted_keys() -> Array[StringName]:
    var keys: Array[StringName] = []
    keys.assign(_values.keys())
    keys.sort()
    return keys


## 상태 전체를 하나의 16진 다이제스트로 접는다.
## 결정론 회귀 테스트가 비교하는 값이 이것이다.
func compute_hash() -> String:
    return SimHash.hash_fields(to_hash_fields())


## 해시 입력이 되는 정규 필드 목록.
## 해시가 어긋났을 때 어느 필드에서 갈렸는지 눈으로 대조하는 용도로 노출한다.
func to_hash_fields() -> Array:
    var fields: Array = [
        ["tick", tick],
        ["rng.seed", rng.get_seed()],
        ["rng.state", rng.get_state()],
        ["values.count", _values.size()],
    ]
    for key in sorted_keys():
        fields.append(["value." + String(key), _values[key]])
    return fields
