class_name Chunk
extends RefCounted

## 세계의 저장 단위 (헌법 P7, DECISIONS 2026-09-06 "청크 16×16 × 층 3").
##
## 16×16 칸 × 층 3 = 768 셀. 셀마다 바이트 둘 — 블록 id 와 현재 내구도.
## 두 값을 PackedByteArray 둘에 평평하게 담는다. 인덱스가 고정이라 같은 세계는
## 늘 같은 바이트열이 되고, 정규형이 구조에서 나온다(P3).
##
## 정규형: id 0(air) 인 셀의 내구도는 반드시 0. [method set_id] 가 이를 강제하고
## [method from_bytes] 가 검사한다.
##
## 값 범위는 0..255 다. 범위 밖 값은 거부한다 — 클램프도 랩어라운드도 하지 않는다.
## PackedByteArray 대입은 256 을 조용히 0 으로 접으므로 대입 전에 반드시 검사한다.
##
## dirty 플래그(P7): 값이 실제로 바뀔 때만 켠다. 언로드 저장은 dirty 이거나 persist 표지가 있는
## 청크만 적으므로(ChunkWorld) 변경을 놓치면 상태가 조용히 유실된다. dirty 는 상태가 아니라 표지이며 digest 에 들어가지 않는다.
##
## 이 클래스는 BlockRegistry 를 모른다. 속성 판단은 호출자가 한다.
## 청크의 월드 좌표도 여기 없다 — 청크를 소유하는 쪽이 키로 든다.

const CHUNK_SIZE := 16
const LAYERS := 3
const LAYER_UNDER := 0
const LAYER_GROUND := 1
const LAYER_UPPER := 2

## 셀 수 = CHUNK_SIZE * CHUNK_SIZE * LAYERS.
const CELL_COUNT := 768

## 직렬화 길이 = CELL_COUNT * 2 (id 바이트열 + 내구도 바이트열).
const BYTE_COUNT := 1536

## 셀 값의 상한. id 와 내구도 모두 한 바이트다.
const MAX_BYTE := 255

## 셀 순 블록 id. 크기 CELL_COUNT.
var _ids := PackedByteArray()

## 셀 순 현재 내구도. 크기 CELL_COUNT. id 0 인 셀은 반드시 0.
var _durability := PackedByteArray()

## 마지막 [method clear_dirty] 이후 값이 바뀌었는가.
var _dirty := false

## 변경 횟수 표지. dirty 가 켜지는 것과 같은 조건(값이 실제로 바뀔 때)에 1 증가한다.
## 해시 밖 — dirty 와 같은 결이라 digest·to_bytes 에 들어가지 않는다. [method clear_dirty] 는
## 건드리지 않는다. [method empty]·[method from_bytes] 직후 0.
var _revision: int = 0


func _init() -> void:
    _ids.resize(CELL_COUNT)
    _durability.resize(CELL_COUNT)


## 셀 인덱스 = (layer * 16 + y) * 16 + x. 범위 밖이면 -1.
## 핫패스 호출자는 둘 중 하나만 한다 — [method in_bounds] 를 먼저 묻고 index_of 를 부르거나,
## index_of 의 -1 만 검사한다. 둘 다 하면 범위 검사가 두 번 든다.
static func index_of(x: int, y: int, layer: int) -> int:
    if not in_bounds(x, y, layer):
        return -1
    return (layer * CHUNK_SIZE + y) * CHUNK_SIZE + x


## 좌표가 청크 안인가.
static func in_bounds(x: int, y: int, layer: int) -> bool:
    return x >= 0 and x < CHUNK_SIZE \
        and y >= 0 and y < CHUNK_SIZE \
        and layer >= 0 and layer < LAYERS


## 전부 air(id 0 · 내구도 0)인 청크. clean.
static func empty() -> Chunk:
    return Chunk.new()


## [method to_bytes] 의 역. 길이가 BYTE_COUNT 가 아니거나 정규형을 깨는 셀이 있으면 null.
## 성공하면 clean — 불러온 직후는 저장할 것이 없다.
static func from_bytes(bytes: PackedByteArray) -> Chunk:
    if bytes.size() != BYTE_COUNT:
        return null
    var chunk := Chunk.new()
    chunk._ids = bytes.slice(0, CELL_COUNT)
    chunk._durability = bytes.slice(CELL_COUNT, BYTE_COUNT)
    for index in CELL_COUNT:
        if chunk._ids[index] == 0 and chunk._durability[index] != 0:
            return null
    return chunk


## 정규 바이트열. 앞 CELL_COUNT 바이트 = _ids, 뒤 CELL_COUNT 바이트 = _durability.
## 이 레이아웃은 [method digest] 와 M1-10 저장 포맷에 묶여 있다 — 바꾸면 저장된 세계와
## 결정론 회귀 스위트의 해시가 전부 깨진다.
func to_bytes() -> PackedByteArray:
    var bytes := PackedByteArray()
    bytes.append_array(_ids)
    bytes.append_array(_durability)
    return bytes


## 셀의 블록 id. 범위 밖은 0(air).
func get_id(x: int, y: int, layer: int) -> int:
    var index := index_of(x, y, layer)
    if index < 0:
        return 0
    return _ids[index]


## 셀의 현재 내구도. 범위 밖은 0.
func get_durability(x: int, y: int, layer: int) -> int:
    var index := index_of(x, y, layer)
    if index < 0:
        return 0
    return _durability[index]


## 셀에 블록을 놓는다. id 0 이면 [param durability] 를 버리고 0 을 쓴다(정규형).
## 범위 밖 좌표·0..255 밖 값은 false 이고 아무것도 바꾸지 않는다.
## 두 바이트가 모두 기존 값과 같으면 false — dirty 도 켜지 않는다.
## 실제로 바뀌면 true 이고 dirty.
func set_id(x: int, y: int, layer: int, id: int, durability: int) -> bool:
    var index := index_of(x, y, layer)
    if index < 0:
        return false
    if id < 0 or id > MAX_BYTE:
        return false
    if durability < 0 or durability > MAX_BYTE:
        return false
    if id == 0:
        durability = 0
    if _ids[index] == id and _durability[index] == durability:
        return false
    _ids[index] = id
    _durability[index] = durability
    _dirty = true
    _revision += 1
    return true


## 셀의 내구도만 바꾼다. 범위 밖 좌표·0..255 밖 값은 false.
## 셀이 air 이면 거부한다(정규형) — air 에 내구도를 주는 길은 없다.
## 같은 값이면 false 이고 dirty 도 켜지 않는다. 바뀌면 true 이고 dirty.
func set_durability(x: int, y: int, layer: int, d: int) -> bool:
    var index := index_of(x, y, layer)
    if index < 0:
        return false
    if d < 0 or d > MAX_BYTE:
        return false
    if _ids[index] == 0:
        return false
    if _durability[index] == d:
        return false
    _durability[index] = d
    _dirty = true
    _revision += 1
    return true


## 마지막 [method clear_dirty] 이후 값이 바뀌었는가.
func is_dirty() -> bool:
    return _dirty


## 저장을 마친 뒤 부른다. revision 은 건드리지 않는다.
func clear_dirty() -> void:
    _dirty = false


## 변경 횟수 표지. 값이 실제로 바뀐 횟수(dirty 와 같은 조건). 해시 밖(dirty 와 같은 결).
func revision() -> int:
    return _revision


## 내용 해시. dirty 는 들어가지 않는다 — 같은 내용은 저장 여부와 무관하게 같은 값이다.
func digest() -> String:
    return SimHash.hash_bytes(to_bytes())
