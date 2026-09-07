class_name WorldState
extends RefCounted

## 시뮬레이션이 소유하는 전체 상태.
##
## 노드 트리와 렌더링을 알지 못한다. 헤드리스로 단독 생성·실행된다.
## 표현 레이어는 이 객체를 읽기만 한다.
##
## 값은 정수만 담는다. 시뮬레이션 로직에 부동소수점을 들이지 않기 위한 제약이다.
##
## M1-6a-2: 틱, 난수원, 이름 붙은 정수 값, 플레이어([member player]), 청크 월드([member chunks])를
## 가진다. 로드 중심은 상태가 아니다 — Simulation.step() 이 플레이어 발 칸에서 유도한다(SIM_ORDER 1-M1b).
## 생존·회로 등 나머지 서브시스템 상태는 M2~M6 에서 붙는다. 붙일 때는 [method to_hash_fields] 에
## 순서 있는 필드로 함께 넣어야 결정론 회귀 테스트가 그것을 지킨다.

## 지금까지 처리를 마친 틱 수. 다음에 실행할 틱 번호이기도 하다.
var tick: int = 0

## 이 월드의 유일한 난수원.
var rng: SimRng

## 청크 월드(P7). 필수 — null 을 허용하지 않는다. 빈 세계 fallback 은 없다.
var chunks: ChunkWorld

## 블록 속성 표. 읽기 전용 — 명령이 속성(`solid` 등)을 물을 때 쓴다. 표는 코드와 같은 층이라
## 상태가 아니고 해시에 들어가지 않는다(DECISIONS 2026-09-06 레지스트리).
var registry: BlockRegistry

## 플레이어 위치·목표·층·방향. 필수. 해시 필드는 values 뒤·chunks 앞에 붙는다.
var player: PlayerState

var _values: Dictionary[StringName, int] = {}


## 네 인자 전부 필수. null 검사는 [Simulation.create] 가 한다.
func _init(p_rng: SimRng, p_chunks: ChunkWorld, p_registry: BlockRegistry, p_player: PlayerState) -> void:
    rng = p_rng
    chunks = p_chunks
    registry = p_registry
    player = p_player


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
        ["values.count", _values.size()],
    ]
    for key in sorted_keys():
        fields.append(["value." + String(key), _values[key]])
    fields.append_array(player.to_hash_fields())
    fields.append_array(chunks.to_hash_fields())
    return fields
