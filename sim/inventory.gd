class_name Inventory
extends RefCounted

## 손에 든 재료. 블록 종류별 개수.
##
## 딕셔너리가 아니라 종류 번호로 색인하는 배열이다. 순회 순서가 항상 같아야
## 상태 해시가 흔들리지 않는다.
##
## 빈 칸은 재료가 아니다. 부순 자리를 재료로 세면 개수가 엉킨다.

var _counts: PackedInt32Array = PackedInt32Array()


func _init() -> void:
    _counts.resize(BlockType.COUNT)
    _counts.fill(0)


func count_of(block_type: int) -> int:
    if not BlockType.is_valid(block_type):
        return 0
    return _counts[block_type]


func add(block_type: int, amount: int) -> void:
    if amount <= 0 or not BlockType.is_solid(block_type):
        return
    _counts[block_type] += amount


## 모자라면 아무것도 빼지 않고 false 를 돌려준다.
func take(block_type: int, amount: int) -> bool:
    if amount <= 0 or not BlockType.is_solid(block_type):
        return false
    if _counts[block_type] < amount:
        return false
    _counts[block_type] -= amount
    return true


## 절반을 떨어뜨린다. 홀수는 남는 쪽이 손해가 되도록 버림한다.
func drop_half() -> void:
    for type in BlockType.COUNT:
        _counts[type] = _counts[type] / 2


func total() -> int:
    var sum := 0
    for count in _counts:
        sum += count
    return sum


func to_hash_fields() -> Array:
    var fields: Array = []
    for type in BlockType.COUNT:
        fields.append(["stock." + BlockType.name_of(type), _counts[type]])
    return fields
