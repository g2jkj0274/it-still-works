class_name Inventory
extends RefCounted

## 손에 든 것 (M1-7a, 헌법 P3·P6, DECISIONS 2026-09-09 "인벤토리: 칸 9 × 스택 64").
##
## 칸으로 나뉘어 있고 칸마다 쌓이는 한계가 있다. 종류마다 수 하나면 무엇이든 무한히 들 수 있어서
## 무엇을 가져갈지 고르는 일이 없고 자원지를 오가는 일에 값이 붙지 않는다. 손이 먼저 모자라야
## M5 아이템 운반의 동기가 된다(P6 — 자동화의 필요는 강제가 아니라 누적에서 나온다).
##
## 평평한 배열 둘(칸 순 블록 id · 칸 순 개수)로 든다. 칸 번호로 색인하므로 순회 순서가 항상
## 같고 상태 해시가 흔들리지 않는다(P3).
##
## 정규형: `amount == 0 ⇔ kind == 0`. 빈 칸은 항상 kind 0 · amount 0 이다. 값을 바꾸는 모든 경로
## ([method add]·[method take]·[method _clear])가 이를 지킨다. 같은 내용은 어느 경로로 왔든 같은
## 해시여야 하기 때문이다.
##
## 이 클래스는 블록 속성 표를 모른다. 부술 수 있는지·놓을 수 있는지는 명령이 표에
## `is_breakable` 로 묻는다. 여기서는 id 의 범위(1..MAX_KIND)와 개수의 부호만 본다.
##
## 이 파일에는 씬 노드·부동소수·난수·파일 IO·순서 비보장 자료구조가 없다.

## 칸 수.
const SLOT_COUNT := 9

## 한 칸에 쌓이는 한계.
const STACK_LIMIT := 64

## 블록 id 상한. 청크 셀의 id 가 한 바이트라 같은 값이다(Chunk.MAX_BYTE). 여기서는 청크를
## 참조하지 않고 상수로 둔다.
const MAX_KIND := 255

## 칸 순 블록 id. 빈 칸은 0.
var _kinds := PackedInt32Array()

## 칸 순 개수. 빈 칸은 0.
var _amounts := PackedInt32Array()


## 칸 [param p_slots] 개. 1 미만은 1.
func _init(p_slots: int = SLOT_COUNT) -> void:
    var slots := maxi(p_slots, 1)
    _kinds.resize(slots)
    _amounts.resize(slots)
    _kinds.fill(0)
    _amounts.fill(0)


# --- 조회 ---

func slot_count() -> int:
    return _kinds.size()


## 그 칸의 블록 id. 범위 밖·빈 칸은 0.
func kind_at(slot: int) -> int:
    if not _is_slot(slot):
        return 0
    return _kinds[slot]


## 그 칸의 개수. 범위 밖·빈 칸은 0.
func amount_at(slot: int) -> int:
    if not _is_slot(slot):
        return 0
    return _amounts[slot]


func is_empty_slot(slot: int) -> bool:
    return amount_at(slot) <= 0


## 그 id 를 통틀어 몇 개 들고 있는가. 여러 칸의 합.
func count_of(id: int) -> int:
    var sum := 0
    for slot in _kinds.size():
        if _kinds[slot] == id:
            sum += _amounts[slot]
    return sum


## 든 것 전부의 수.
func total() -> int:
    var sum := 0
    for amount in _amounts:
        sum += amount
    return sum


## 그 id 를 하나라도 더 들 수 있는가. 쌓다 만 칸이나 빈 칸이 있으면 든다.
## 범위 밖 id 는 false.
func has_room_for(id: int) -> bool:
    if not _is_kind(id):
        return false
    for slot in _kinds.size():
        if _amounts[slot] <= 0:
            return true
        if _kinds[slot] == id and _amounts[slot] < STACK_LIMIT:
            return true
    return false


# --- 변경 ---

## 넣는다. 쌓다 만 칸부터 채우고 그다음 빈 칸이다. **다 넣지 못하면 넣은 만큼만 넣고 남은 수를
## 돌려준다.** 조용히 버리지 않는다 — 부른 쪽이 남은 것을 어떻게 할지 정한다.
## 범위 밖 id·0 이하 개수는 아무것도 바꾸지 않고 `maxi(amount, 0)` 을 돌려준다.
func add(id: int, amount: int) -> int:
    if amount <= 0 or not _is_kind(id):
        return maxi(amount, 0)

    var left := amount
    # 쌓다 만 칸부터. 그래야 빈 칸이 덜 줄어든다.
    for slot in _kinds.size():
        if left <= 0:
            break
        if _kinds[slot] != id or _amounts[slot] <= 0:
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
        _kinds[slot] = id
        _amounts[slot] = fits
        left -= fits

    return left


## 뺀다. 모자라면 **아무것도 빼지 않고** false. 성공하면 뒤 칸부터 뺀다 — 앞 칸이 오래 남는다.
## 범위 밖 id·0 이하 개수는 false. 다 빠진 칸은 정규형(0:0)으로 비운다.
func take(id: int, amount: int) -> bool:
    if amount <= 0 or not _is_kind(id):
        return false
    if count_of(id) < amount:
        return false

    var left := amount
    for i in _kinds.size():
        if left <= 0:
            break
        var slot := _kinds.size() - 1 - i
        if _kinds[slot] != id:
            continue
        var taken := mini(left, _amounts[slot])
        _amounts[slot] -= taken
        left -= taken
        if _amounts[slot] <= 0:
            _clear(slot)
    return true


# --- 해시 ---

## 해시 입력이 되는 정규 필드 목록. 순서 고정: 칸 수 뒤에 칸마다 "kind:amount".
func to_hash_fields() -> Array:
    var fields: Array = [["inventory.slots", _kinds.size()]]
    for slot in _kinds.size():
        fields.append(["inventory.%d" % slot, "%d:%d" % [_kinds[slot], _amounts[slot]]])
    return fields


# --- 내부 ---

func _is_slot(slot: int) -> bool:
    return slot >= 0 and slot < _kinds.size()


## 들 수 있는 id 범위. 0 은 빈 칸 표지라 든 것이 될 수 없다.
func _is_kind(id: int) -> bool:
    return id > 0 and id <= MAX_KIND


## 칸을 정규형 빈 칸으로.
func _clear(slot: int) -> void:
    _kinds[slot] = 0
    _amounts[slot] = 0
