class_name Inventory
extends RefCounted

## 손에 든 재료. 블록 종류별 개수.
##
## 딕셔너리가 아니라 종류 번호로 색인하는 배열이다. 순회 순서가 항상 같아야
## 상태 해시가 흔들리지 않는다.
##
## 빈 칸은 재료가 아니다. 부순 자리를 재료로 세면 개수가 엉킨다.
##
## 묶음만은 종류 번호로 셀 수 없다. 같은 묶음이라도 안에 든 것이 저마다 달라서
## 한 칸에 몰아 세면 무엇이 몇 개인지 알 수 없게 된다. 묶음 번호마다 따로 센다.

var _counts: PackedInt32Array = PackedInt32Array()

## 묶음 번호별 개수. 새 묶음이 생기면 그만큼 늘어난다.
var _bundles: PackedInt32Array = PackedInt32Array()


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
    if BlockType.is_uniquely_made(block_type):
        return
    _counts[block_type] += amount


## 모자라면 아무것도 빼지 않고 false 를 돌려준다.
func take(block_type: int, amount: int) -> bool:
    if amount <= 0 or not BlockType.is_solid(block_type):
        return false
    if BlockType.is_uniquely_made(block_type):
        return false
    if _counts[block_type] < amount:
        return false
    _counts[block_type] -= amount
    return true


## 묶음 번호별로 몇 개를 들고 있는가.
func count_of_bundle(bundle_id: int) -> int:
    if bundle_id < 0 or bundle_id >= _bundles.size():
        return 0
    return _bundles[bundle_id]


func add_bundle(bundle_id: int, amount: int) -> void:
    if bundle_id < 0 or amount <= 0:
        return
    if bundle_id >= _bundles.size():
        _bundles.resize(bundle_id + 1)
    _bundles[bundle_id] += amount


func take_bundle(bundle_id: int, amount: int) -> bool:
    if amount <= 0 or count_of_bundle(bundle_id) < amount:
        return false
    _bundles[bundle_id] -= amount
    return true


## 세어 본 적 있는 묶음 번호의 수. 화면이 훑을 범위를 잡는 데 쓴다.
func bundle_slots() -> int:
    return _bundles.size()


## 절반을 떨어뜨린다. 홀수는 남는 쪽이 손해가 되도록 버림한다.
func drop_half() -> void:
    for type in BlockType.COUNT:
        _counts[type] = _counts[type] / 2
    for i in _bundles.size():
        _bundles[i] = _bundles[i] / 2


func total() -> int:
    var sum := 0
    for count in _counts:
        sum += count
    for count in _bundles:
        sum += count
    return sum


func to_hash_fields() -> Array:
    var fields: Array = []
    for type in BlockType.COUNT:
        fields.append(["stock." + BlockType.name_of(type), _counts[type]])
    for i in _bundles.size():
        fields.append(["stock.bundle.%d" % i, _bundles[i]])
    return fields
