class_name ChunkWorld
extends RefCounted

## 청크 월드 자료구조 (M1-4a, 헌법 P7).
##
## 로드 중심 주변 반경 안의 청크를 들고 있고, 반경을 벗어난 청크는 언로드한다.
## 언로드된 청크의 시뮬레이션은 멈춘다(P7). 그 청크의 상태(블록 id · 현재 내구도)는
## 생성값과 다를 수 있으면 바이트열 스냅샷으로 보존되고, 다시 로드될 때 복원된다.
## 생성값과 같다고 확신할 수 있는 청크(clean 이고 스냅샷에서 오지 않은 것)는 버린다 —
## 다시 로드하면 생성기가 같은 바이트열을 만들기 때문이다(ChunkGenerator 는 좌표의 순수 함수).
##
## 불변식: 한 키는 `_loaded` 와 `_snapshots` 중 정확히 하나에만 있다(둘 다 없을 수는 있다).
## `_persist` 의 키는 항상 `_loaded` 에 있다.
##
## 결정론(P3): 로드·언로드 순서는 (cy, cx) 정렬로 고정한다. Dictionary 순회 결과를 정렬 없이
## 판단에 쓰지 않는다. 해시 필드도 정렬된 순서로만 내보낸다.
##
## 이 파일에는 Node·부동소수·난수·파일 IO 가 없다. 정수 좌표와 바이트열만 다룬다.
## 렌더러(view)는 [method get_chunk] · [method loaded_sorted] 로 읽기만 한다.

## P7 "플레이어 주변 로드 반경은 상수 하나로 정의되고 문서화된다" — 그 상수가 이것이다.
## 중심 청크 기준 체비쇼프 거리 ≤ LOAD_RADIUS 인 청크가 로드된다 → (2R+1)² = 25 청크.
const LOAD_RADIUS := 2

## 월드 좌표 → 청크 좌표 시프트. `1 << CHUNK_SHIFT == Chunk.CHUNK_SIZE`.
const CHUNK_SHIFT := 4

## 월드 좌표 → 청크 안 로컬 좌표 마스크. `CHUNK_MASK == Chunk.CHUNK_SIZE - 1`.
const CHUNK_MASK := 15

var _generator: ChunkGenerator

## 로드된 청크. 키 = 청크 좌표.
var _loaded: Dictionary[Vector2i, Chunk] = {}

## 언로드된, 생성값과 다를 수 있는 청크의 바이트열(P7 보존).
var _snapshots: Dictionary[Vector2i, PackedByteArray] = {}

## "이 로드된 청크는 스냅샷에서 왔다" 표지. dirty 가 아니어도 언로드 시 스냅샷을 다시 만든다 —
## 스냅샷에서 온 청크는 생성값과 다를 수 있고, Chunk 는 자기 출처를 모르기 때문이다.
## 표지일 뿐 상태가 아니다. 해시에 넣지 않는다.
var _persist: Dictionary[Vector2i, bool] = {}

var _center := Vector2i.ZERO
var _has_center := false


func _init(generator: ChunkGenerator) -> void:
    _generator = generator


# --- 좌표 변환 ---

## 월드 좌표 한 축 → 청크 좌표. 산술 시프트라 음수에서도 floor 다 (-1 → -1, -17 → -2).
## 모든 좌표 변환은 이 함수와 [method local_of] 만 거친다.
static func chunk_of(w: int) -> int:
    return w >> CHUNK_SHIFT


## 월드 좌표 한 축 → 청크 안 로컬 좌표 0..15. 음수에서도 0..15 다 (-1 → 15).
static func local_of(w: int) -> int:
    return w & CHUNK_MASK


# --- 로드 중심 ---

## 로드 중심을 옮긴다. 반경 밖 청크를 (cy, cx) 순으로 언로드한 뒤, 반경 안 빈 자리를
## cy 바깥·cx 안쪽 루프 순으로 로드한다. 같은 중심으로 다시 부르면 아무 일도 없다.
func set_center(cx: int, cy: int) -> void:
    _center = Vector2i(cx, cy)
    _has_center = true

    var to_unload: Array = []
    for key: Vector2i in _loaded.keys():
        if _chebyshev(key, _center) > LOAD_RADIUS:
            to_unload.append(key)
    for key: Vector2i in _sort_keys(to_unload):
        _unload(key)

    for y in range(cy - LOAD_RADIUS, cy + LOAD_RADIUS + 1):
        for x in range(cx - LOAD_RADIUS, cx + LOAD_RADIUS + 1):
            var key := Vector2i(x, y)
            if not _loaded.has(key):
                _load(key)


## 스냅샷이 있으면 복원하고 persist 표지를 켠다. 없으면 생성한다.
## 스냅샷 바이트열은 [method restore_snapshot] 이나 [method _unload] 가 만든 것이라 from_bytes 가
## null 을 낼 수 없다. 그래도 null 이면 생성값을 쓰고 persist 는 켜지 않되, 스냅샷은 지우지
## 않고 남긴다 (assert 대신 — 세계가 멈추는 것보다 지형이 되돌아가는 쪽이 P5 에 맞고, 바이트열을
## 버리지 않아야 P7 유실 경로가 코드에 남지 않는다. 감사 2026-09-08).
func _load(key: Vector2i) -> void:
    if _snapshots.has(key):
        var restored := Chunk.from_bytes(_snapshots[key])
        if restored != null:
            _snapshots.erase(key)
            _loaded[key] = restored
            _persist[key] = true
            return
    _loaded[key] = _generator.generate(key.x, key.y)


## dirty 이거나 스냅샷에서 온 청크는 바이트열로 남긴다. 그 외는 생성값과 같으므로 버린다.
func _unload(key: Vector2i) -> void:
    var chunk: Chunk = _loaded[key]
    if chunk.is_dirty() or _persist.has(key):
        _snapshots[key] = chunk.to_bytes()
    _loaded.erase(key)
    _persist.erase(key)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
    return maxi(absi(a.x - b.x), absi(a.y - b.y))


# --- 조회 ---

func is_loaded(cx: int, cy: int) -> bool:
    return _loaded.has(Vector2i(cx, cy))


func loaded_count() -> int:
    return _loaded.size()


func snapshot_count() -> int:
    return _snapshots.size()


func has_center() -> bool:
    return _has_center


func center() -> Vector2i:
    return _center


## 로드된 청크. 안 로드면 null. view 가 그릴 때 읽는다.
func get_chunk(cx: int, cy: int) -> Chunk:
    var key := Vector2i(cx, cy)
    if not _loaded.has(key):
        return null
    return _loaded[key]


# --- 월드 좌표 셀 접근 ---
# 언로드된 청크의 시뮬레이션은 멈춘다(P7). 안 로드된 칸은 읽으면 0, 쓰면 false 다 —
# 스냅샷을 몰래 깨우지 않는다.

func get_id_at(wx: int, wy: int, layer: int) -> int:
    var chunk := get_chunk(chunk_of(wx), chunk_of(wy))
    if chunk == null:
        return 0
    return chunk.get_id(local_of(wx), local_of(wy), layer)


func get_durability_at(wx: int, wy: int, layer: int) -> int:
    var chunk := get_chunk(chunk_of(wx), chunk_of(wy))
    if chunk == null:
        return 0
    return chunk.get_durability(local_of(wx), local_of(wy), layer)


## 안 로드면 false. 그 외는 [method Chunk.set_id] 의 반환값 그대로(값이 바뀌었을 때만 true).
func set_id_at(wx: int, wy: int, layer: int, id: int, durability: int) -> bool:
    var chunk := get_chunk(chunk_of(wx), chunk_of(wy))
    if chunk == null:
        return false
    return chunk.set_id(local_of(wx), local_of(wy), layer, id, durability)


## 안 로드면 false. 그 외는 [method Chunk.set_durability] 의 반환값 그대로.
func set_durability_at(wx: int, wy: int, layer: int, d: int) -> bool:
    var chunk := get_chunk(chunk_of(wx), chunk_of(wy))
    if chunk == null:
        return false
    return chunk.set_durability(local_of(wx), local_of(wy), layer, d)


# --- 저장 지원 (M1-10) ---

## 언로드 스냅샷을 (cy, cx) 순으로. 각 원소 `[Vector2i, PackedByteArray]`.
func snapshots_sorted() -> Array:
    var out: Array = []
    for key: Vector2i in _sort_keys(_snapshots.keys()):
        out.append([key, _snapshots[key]])
    return out


## 로드된 청크를 (cy, cx) 순으로. 각 원소 `[Vector2i, Chunk]`. M1-10 이 dirty·persist 청크를
## 적을 때와 view 순회용.
func loaded_sorted() -> Array:
    var out: Array = []
    for key: Vector2i in _sort_keys(_loaded.keys()):
        out.append([key, _loaded[key]])
    return out


## 저장 파일의 스냅샷을 되돌린다. 키가 로드돼 있으면 false(불변식). 바이트열이 Chunk 정규형이
## 아니면 false. 성공하면 복사본을 보관하고 true.
func restore_snapshot(cx: int, cy: int, bytes: PackedByteArray) -> bool:
    var key := Vector2i(cx, cy)
    if _loaded.has(key):
        return false
    if Chunk.from_bytes(bytes) == null:
        return false
    _snapshots[key] = bytes.duplicate()
    return true


# --- 해시 ---

## 해시 입력이 되는 정규 필드 목록. 순서 고정.
## dirty·persist 는 표지라 들어가지 않는다 — 같은 내용은 어느 경로로 왔든 같은 해시다.
func to_hash_fields() -> Array:
    var fields: Array = []
    fields.append(["chunks.has_center", 1 if _has_center else 0])
    if _has_center:
        fields.append(["chunks.center", "%d,%d" % [_center.x, _center.y]])
    else:
        fields.append(["chunks.center", "0,0"])
    fields.append(["chunks.loaded", _loaded.size()])
    for entry: Array in loaded_sorted():
        var key: Vector2i = entry[0]
        var chunk: Chunk = entry[1]
        fields.append(["chunk.%d,%d" % [key.x, key.y], chunk.digest()])
    fields.append(["chunks.snapshots", _snapshots.size()])
    for entry: Array in snapshots_sorted():
        var key: Vector2i = entry[0]
        var bytes: PackedByteArray = entry[1]
        fields.append(["snapshot.%d,%d" % [key.x, key.y], SimHash.hash_bytes(bytes)])
    return fields


func compute_hash() -> String:
    return SimHash.hash_fields(to_hash_fields())


## (cy, cx) 순 정렬. Vector2i 기본 `<` 에 기대지 않는다.
static func _sort_keys(keys: Array) -> Array:
    var sorted := keys.duplicate()
    sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        return a.y < b.y if a.y != b.y else a.x < b.x)
    return sorted
