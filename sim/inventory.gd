class_name Inventory
extends RefCounted

## 손에 든 것. **칸으로 나뉘어 있고 칸마다 쌓이는 한계가 있다.**
##
## 예전에는 종류마다 세는 수 하나였다. 그러면 무엇이든 무한히 들 수 있어서
## 무엇을 가져갈지 고르는 일이 없고, 자원지를 오가는 일에 값이 붙지 않는다.
## 왕복이 자동 운반 장치의 동기가 되려면(스펙 §3.6) 손이 먼저 모자라야 한다.
##
## 칸 하나는 [무엇, 몇 개, 어느 것] 이다. **어느 것**은 종류만으로는
## 가려지지 않는 물건을 위한 자리다. 종류와 그것이 둘 다 같아야 한 칸에 쌓인다.
##
## 딕셔너리를 쓰지 않는다. 칸 번호로 색인하는 평평한 배열이라 순회 순서가
## 항상 같고 상태 해시가 흔들리지 않는다.

## 칸 수. 앞의 [constant HOTBAR_SLOTS] 개가 손에 잡히는 줄이다.
const SLOT_COUNT := 36
const HOTBAR_SLOTS := 9

## 한 칸에 쌓이는 한계.
const STACK_LIMIT := 64

## 빈 칸을 뜻하는 값.
const NO_SLOT := -1

var _kinds: PackedInt32Array = PackedInt32Array()
var _amounts: PackedInt32Array = PackedInt32Array()
var _variants: PackedInt32Array = PackedInt32Array()


func _init(p_slots: int = SLOT_COUNT) -> void:
    var slots := maxi(p_slots, 1)
    _kinds.resize(slots)
    _amounts.resize(slots)
    _variants.resize(slots)
    _kinds.fill(BlockType.EMPTY)
    _amounts.fill(0)
    _variants.fill(0)


func slot_count() -> int:
    return _kinds.size()


func kind_at(slot: int) -> int:
    if not _is_slot(slot):
        return BlockType.EMPTY
    return _kinds[slot]


func amount_at(slot: int) -> int:
    if not _is_slot(slot):
        return 0
    return _amounts[slot]


## 그 칸에 든 것이 어느 것인지. 지금은 늘 0 이다.
##
## 종류만으로 가려지지 않는 물건이 생기면 여기가 그 자리다.
func variant_at(slot: int) -> int:
    if not _is_slot(slot):
        return 0
    return _variants[slot]


func is_empty_slot(slot: int) -> bool:
    return amount_at(slot) <= 0


## 그 종류를 통틀어 몇 개 들고 있는가.
func count_of(block_type: int) -> int:
    var total := 0
    for slot in _kinds.size():
        if _kinds[slot] == block_type:
            total += _amounts[slot]
    return total



func total() -> int:
    var sum := 0
    for amount in _amounts:
        sum += amount
    return sum


## 들 수 있는가. 쌓다 만 칸이나 빈 칸이 있으면 든다.
func has_room_for(block_type: int, variant: int = 0) -> bool:
    return _room_for(block_type, variant) > 0


## 넣는다. **다 넣지 못하면 넣은 만큼만 넣고 남은 수를 돌려준다.**
##
## 조용히 버리지 않는다. 부른 쪽이 남은 것을 어떻게 할지 정한다.
func add(block_type: int, amount: int, variant: int = 0) -> int:
    if amount <= 0 or not BlockType.is_carryable(block_type):
        return maxi(amount, 0)

    var left := amount
    # 쌓다 만 칸부터 채운다. 그래야 빈 칸이 덜 줄어든다.
    for slot in _kinds.size():
        if left <= 0:
            break
        if _kinds[slot] != block_type or _variants[slot] != variant:
            continue
        var fits := mini(left, STACK_LIMIT - _amounts[slot])
        _amounts[slot] += fits
        left -= fits

    for slot in _kinds.size():
        if left <= 0:
            break
        if _amounts[slot] > 0:
            continue
        var fits := mini(left, STACK_LIMIT)
        _kinds[slot] = block_type
        _variants[slot] = variant
        _amounts[slot] = fits
        left -= fits

    return left



## 뺀다. 모자라면 **아무것도 빼지 않고** false 를 돌려준다.
func take(block_type: int, amount: int, variant: int = 0) -> bool:
    if amount <= 0 or not BlockType.is_carryable(block_type):
        return false
    if _held(block_type, variant) < amount:
        return false

    var left := amount
    # 뒤에서부터 뺀다. 앞줄(손에 잡히는 줄)이 오래 남는다.
    for i in _kinds.size():
        if left <= 0:
            break
        var slot := _kinds.size() - 1 - i
        if _kinds[slot] != block_type or _variants[slot] != variant:
            continue
        var taken := mini(left, _amounts[slot])
        _amounts[slot] -= taken
        left -= taken
        if _amounts[slot] <= 0:
            _clear(slot)
    return true



## 두 칸을 맞바꾼다. 같은 것이면 한쪽으로 모은다.
func move(from: int, to: int) -> void:
    if not _is_slot(from) or not _is_slot(to) or from == to:
        return

    if (_kinds[from] == _kinds[to] and _variants[from] == _variants[to]
            and _amounts[from] > 0 and _amounts[to] > 0):
        var fits := mini(_amounts[from], STACK_LIMIT - _amounts[to])
        _amounts[to] += fits
        _amounts[from] -= fits
        if _amounts[from] <= 0:
            _clear(from)
        return

    var kind := _kinds[from]
    var amount := _amounts[from]
    var variant := _variants[from]
    _kinds[from] = _kinds[to]
    _amounts[from] = _amounts[to]
    _variants[from] = _variants[to]
    _kinds[to] = kind
    _amounts[to] = amount
    _variants[to] = variant


## 그 칸의 절반을 [param to] 로 옮긴다. 홀수는 집은 쪽이 많이 갖는다.
##
## 광석 마흔여덟 개를 한 칸씩 나누는 것이 아니라 절반씩 가르는 것이
## 마인크래프트의 손놀림이다.
func split(from: int, to: int) -> void:
    if not _is_slot(from) or not _is_slot(to) or from == to:
        return
    var amount := _amounts[from]
    if amount <= 1:
        move(from, to)
        return

    var half := amount / 2
    var kind := _kinds[from]
    var variant := _variants[from]
    var left := put_slot(to, kind, half, variant)
    var moved := half - int(left[1])
    if moved <= 0:
        return

    _amounts[from] -= moved
    if _amounts[from] <= 0:
        _clear(from)


## 그 칸의 것을 통째로 꺼낸다. [무엇, 몇 개, 어느 것].
func take_slot(slot: int) -> Array:
    if not _is_slot(slot) or _amounts[slot] <= 0:
        return [BlockType.EMPTY, 0, 0]
    var held := [_kinds[slot], _amounts[slot], _variants[slot]]
    _clear(slot)
    return held


## 그 칸에 통째로 넣는다. 넣지 못한 것을 돌려준다.
func put_slot(slot: int, kind: int, amount: int, variant: int = 0) -> Array:
    if not _is_slot(slot) or amount <= 0:
        return [kind, amount, variant]

    if _amounts[slot] <= 0:
        var fits := mini(amount, STACK_LIMIT)
        _kinds[slot] = kind
        _amounts[slot] = fits
        _variants[slot] = variant
        return [kind, amount - fits, variant]

    if _kinds[slot] == kind and _variants[slot] == variant:
        var room := mini(amount, STACK_LIMIT - _amounts[slot])
        _amounts[slot] += room
        return [kind, amount - room, variant]

    return [kind, amount, variant]


## 절반을 떨어뜨린다. 홀수는 남는 쪽이 손해가 되도록 버림한다.
func drop_half() -> void:
    for slot in _kinds.size():
        _amounts[slot] = _amounts[slot] / 2
        if _amounts[slot] <= 0:
            _clear(slot)


func to_hash_fields() -> Array:
    var fields: Array = [["stock.slots", _kinds.size()]]
    for slot in _kinds.size():
        fields.append(["stock.%d" % slot, "%d:%d:%d" % [
            _kinds[slot], _amounts[slot], _variants[slot]]])
    return fields


func _is_slot(slot: int) -> bool:
    return slot >= 0 and slot < _kinds.size()


func _clear(slot: int) -> void:
    _kinds[slot] = BlockType.EMPTY
    _amounts[slot] = 0
    _variants[slot] = 0


func _held(block_type: int, variant: int) -> int:
    var total := 0
    for slot in _kinds.size():
        if _kinds[slot] == block_type and _variants[slot] == variant:
            total += _amounts[slot]
    return total


## 더 들 수 있는 수.
func _room_for(block_type: int, variant: int) -> int:
    if not BlockType.is_carryable(block_type):
        return 0
    var room := 0
    for slot in _kinds.size():
        if _amounts[slot] <= 0:
            room += STACK_LIMIT
        elif _kinds[slot] == block_type and _variants[slot] == variant:
            room += STACK_LIMIT - _amounts[slot]
    return room
