class_name SimRng
extends RefCounted

## 시뮬레이션 전용 난수원.
##
## 시뮬레이션 안에서 난수가 필요하면 반드시 이 클래스의 단일 인스턴스를 거친다.
## 전역 [code]randi()[/code] / [code]randf()[/code] 는 호출 순서에 따라 결과가 달라져
## 결정론을 깨므로 사용하지 않는다.
##
## 실수 난수는 의도적으로 노출하지 않는다. 시뮬레이션은 정수 격자만 다룬다.

var _seed: int
var _rng: RandomNumberGenerator


func _init(p_seed: int = 0) -> void:
    _seed = p_seed
    _rng = RandomNumberGenerator.new()
    reset()


## 초기 시드 상태로 되돌린다. 같은 시드는 같은 수열을 낸다.
func reset() -> void:
    _rng.seed = _seed


func get_seed() -> int:
    return _seed


## 현재 내부 상태. 월드 상태 해시와 저장/복원에 쓰인다.
func get_state() -> int:
    return _rng.state


func set_state(p_state: int) -> void:
    _rng.state = p_state


## 다음 정수 난수.
func next_int() -> int:
    return _rng.randi()


## from..to 범위(양끝 포함)의 정수 난수.
func next_range(from: int, to: int) -> int:
    return _rng.randi_range(from, to)
