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

## 섬의 복셀 격자.
var grid: VoxelGrid

## 플레이어 캐릭터.
var character: CharacterState

## 손에 든 재료.
var inventory: Inventory

## 쓰러졌을 때 다시 일어나는 자리.
var spawn: Vector3i = Vector3i.ZERO

## 월드에 놓인 회로.
var circuit: Circuit

## 생존 지표.
var vitals: Vitals

## 지금 나와 있는 위협들.
var threats: ThreatField

## 밭에 심긴 작물들.
var crops: CropField

var _values: Dictionary[StringName, int] = {}


func _init(p_rng: SimRng = null) -> void:
    rng = p_rng if p_rng != null else SimRng.new(0)
    grid = VoxelGrid.new()
    character = CharacterState.new()
    inventory = Inventory.new()
    circuit = Circuit.new()
    vitals = Vitals.new()
    threats = ThreatField.new()
    crops = CropField.new()


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


## 항상 사전순으로 정렬된 키를 돌려준다.
## 딕셔너리 순회 순서는 보장되지 않으므로 시뮬레이션 판단에 직접 쓰지 않는다.
##
## 주의: StringName 끼리의 비교는 사전순이 아니라 내부 포인터 순이다.
## Array[StringName].sort() 를 그대로 쓰면 실행마다 순서가 달라져 결정론이 깨진다.
## 반드시 String 으로 바꾼 뒤 정렬한다.
func sorted_keys() -> Array[StringName]:
    var names: Array[String] = []
    for key: StringName in _values.keys():
        names.append(String(key))
    names.sort()

    var keys: Array[StringName] = []
    for name in names:
        keys.append(StringName(name))
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
        ["grid.digest", grid.digest()],
        ["character.x", character.sub_position.x],
        ["character.y", character.sub_position.y],
        ["character.z", character.sub_position.z],
        ["character.target.x", character.move_target.x],
        ["character.target.y", character.move_target.y],
        ["character.target.z", character.move_target.z],
        ["character.facing.x", character.facing.x],
        ["character.facing.y", character.facing.y],
        ["values.count", _values.size()],
    ]
    fields.append_array(inventory.to_hash_fields())
    fields.append_array(circuit.to_hash_fields())
    fields.append_array(vitals.to_hash_fields())
    fields.append_array(threats.to_hash_fields())
    fields.append_array(crops.to_hash_fields())
    for key in sorted_keys():
        fields.append(["value." + String(key), _values[key]])
    return fields
