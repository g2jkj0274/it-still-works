class_name TerrainTable
extends RefCounted

## 지형 생성 규칙 표 (M1-3, 헌법 P7).
##
## `data/terrain.json` 을 읽어 [ChunkGenerator] 가 쓰는 역할별 블록 후보를 평평한 배열에 담는다.
##   - under_zones   : 지하층 굵은 격자 한 칸을 채우는 블록 후보. 전부 solid.
##   - ground_zones  : 지상층 굵은 격자 한 칸의 바탕 블록 후보. air(0) 또는 solid.
##   - ground_scatter: 지상층 셀 단위로 바탕 위에 흩뿌리는 블록. per_256 = 256 분의 밀도. 합 ≤ 256.
## 표는 블록 이름을 모른다 — id 와 레지스트리 속성으로만 검증한다(P2).
##
## 이 파일이 파싱 경계다. JSON·FileAccess·실수→정수 변환은 여기에만 있고 ChunkGenerator 에는 없다.
##
## 표는 상태가 아니라 규칙이다(DECISIONS 2026-09-06 레지스트리 항목과 같다). 상태 해시에 넣지 않고
## 저장 파일에 [method digest] 를 적어 다른 표로 불러오는 것을 막는다.
## 파싱이 끝나면 Dictionary 는 버린다. 순서 비보장 자료구조를 판단 근거로 남기지 않는다.

const DEFAULT_PATH := "res://data/terrain.json"

## 밀도 분모. per_256 은 0..MAX_PER_256, 흩뿌림 항목의 합도 MAX_PER_256 이하.
const MAX_PER_256 := 256

## 최상위 키. 순서는 [method digest] 의 필드 순서이기도 하다.
const _KEYS: PackedStringArray = ["under_zones", "ground_zones", "ground_scatter"]

## 흩뿌림 항목의 키.
const _SCATTER_KEYS: PackedStringArray = ["id", "per_256"]

## 지하 지대 후보 id. 표 순서 보존.
var _under_zones := PackedInt32Array()

## 지상 지대 후보 id. 표 순서 보존.
var _ground_zones := PackedInt32Array()

## 흩뿌림 블록 id. 표 순서 보존 — 생성기는 이 순서로 누적 문턱을 비교한다.
var _scatter_ids := PackedInt32Array()

## 흩뿌림 밀도. _scatter_ids 와 같은 인덱스.
var _scatter_per_256 := PackedInt32Array()


## 기본 표 `res://data/terrain.json` 을 읽는다. 파일이 없거나 검증에 실패하면 null.
static func load_default(registry: BlockRegistry) -> TerrainTable:
    if not FileAccess.file_exists(DEFAULT_PATH):
        return null
    return from_text(FileAccess.get_file_as_string(DEFAULT_PATH), registry)


## JSON 원문에서 표를 만든다. 검증에 하나라도 걸리면 null.
##   - registry 가 null 이면 null
##   - 최상위는 Dictionary, 키 집합은 under_zones·ground_zones·ground_scatter 와 정확히 같다
##   - 세 배열 모두 비어 있지 않다. 순서는 보존한다
##   - 모든 id 는 0 이상의 정수이고 registry.count() 미만 (JSON 실수는 정수값일 때만 받는다)
##   - under_zones 후보는 전부 solid
##   - ground_zones 후보는 air(0) 또는 solid
##   - ground_scatter 항목은 키가 id·per_256 둘, id 는 solid, per_256 은 0..256 정수, 합 ≤ 256
static func from_text(text: String, registry: BlockRegistry) -> TerrainTable:
    if registry == null:
        return null
    var json := JSON.new()
    if json.parse(text) != OK:
        return null
    var data: Variant = json.data
    if typeof(data) != TYPE_DICTIONARY:
        return null
    var root: Dictionary = data
    if not _has_exact_keys(root, _KEYS):
        return null
    var table := TerrainTable.new()
    if not _read_zone_list(root[_KEYS[0]], registry, false, table._under_zones):
        return null
    if not _read_zone_list(root[_KEYS[1]], registry, true, table._ground_zones):
        return null
    if not _read_scatter_list(root[_KEYS[2]], registry, table):
        return null
    return table


## 지하 지대 후보 수.
func under_zone_count() -> int:
    return _under_zones.size()


## [param i] 번째 지하 지대 후보 id. 범위 밖은 0.
func under_zone(i: int) -> int:
    if i < 0 or i >= _under_zones.size():
        return 0
    return _under_zones[i]


## 지상 지대 후보 수.
func ground_zone_count() -> int:
    return _ground_zones.size()


## [param i] 번째 지상 지대 후보 id. 범위 밖은 0.
func ground_zone(i: int) -> int:
    if i < 0 or i >= _ground_zones.size():
        return 0
    return _ground_zones[i]


## 흩뿌림 항목 수.
func scatter_count() -> int:
    return _scatter_ids.size()


## [param i] 번째 흩뿌림 블록 id. 범위 밖은 0.
func scatter_id(i: int) -> int:
    if i < 0 or i >= _scatter_ids.size():
        return 0
    return _scatter_ids[i]


## [param i] 번째 흩뿌림 밀도(256 분의). 범위 밖은 0.
func scatter_per_256(i: int) -> int:
    if i < 0 or i >= _scatter_per_256.size():
        return 0
    return _scatter_per_256[i]


## 표의 내용 해시. 원문이 아니라 파싱된 배열에서 만들므로 공백·키 순서에 영향받지 않는다.
## 세 목록의 순서가 그대로 들어가므로 후보 순서가 바뀌면 값도 바뀐다 — 생성 결과도 바뀌기 때문이다.
func digest() -> String:
    var fields: Array = []
    fields.append(["under.count", under_zone_count()])
    for i in under_zone_count():
        fields.append(["under.%d" % i, _under_zones[i]])
    fields.append(["ground.count", ground_zone_count()])
    for i in ground_zone_count():
        fields.append(["ground.%d" % i, _ground_zones[i]])
    fields.append(["scatter.count", scatter_count()])
    for i in scatter_count():
        fields.append(["scatter.%d.id" % i, _scatter_ids[i]])
        fields.append(["scatter.%d.per_256" % i, _scatter_per_256[i]])
    return SimHash.hash_fields(fields)


## 지대 후보 목록을 읽어 [param out] 에 채운다. 비어 있거나 한 항목이라도 어긋나면 false.
## [param allow_air] 가 true 면 id 0 도 받는다. 그 외는 solid 여야 한다.
static func _read_zone_list(value: Variant, registry: BlockRegistry, allow_air: bool, out: PackedInt32Array) -> bool:
    if typeof(value) != TYPE_ARRAY:
        return false
    var items: Array = value
    if items.is_empty():
        return false
    for item: Variant in items:
        var id := _to_non_negative_int(item)
        if id < 0 or id >= registry.count():
            return false
        if id == 0:
            if not allow_air:
                return false
        elif not registry.has_at(id, BlockRegistry.ATTR_SOLID):
            return false
        out.append(id)
    return true


## 흩뿌림 목록을 읽어 table 의 두 배열에 채운다. 비어 있거나 한 항목이라도 어긋나면 false.
static func _read_scatter_list(value: Variant, registry: BlockRegistry, table: TerrainTable) -> bool:
    if typeof(value) != TYPE_ARRAY:
        return false
    var items: Array = value
    if items.is_empty():
        return false
    var total := 0
    for item: Variant in items:
        if typeof(item) != TYPE_DICTIONARY:
            return false
        var row: Dictionary = item
        if not _has_exact_keys(row, _SCATTER_KEYS):
            return false
        var id := _to_non_negative_int(row[_SCATTER_KEYS[0]])
        if id < 0 or id >= registry.count():
            return false
        if not registry.has_at(id, BlockRegistry.ATTR_SOLID):
            return false
        var per_256 := _to_non_negative_int(row[_SCATTER_KEYS[1]])
        if per_256 < 0 or per_256 > MAX_PER_256:
            return false
        total += per_256
        if total > MAX_PER_256:
            return false
        table._scatter_ids.append(id)
        table._scatter_per_256.append(per_256)
    return true


## 딕셔너리의 키 집합이 [param keys] 와 정확히 같은가. 키 수가 같고 필수 키가 전부 있으면
## 남는 키도 없다 — 딕셔너리 순회 없이 판정한다.
static func _has_exact_keys(dict: Dictionary, keys: PackedStringArray) -> bool:
    if dict.size() != keys.size():
        return false
    for key in keys:
        if not dict.has(key):
            return false
    return true


## JSON 의 수를 0 이상의 정수로 되돌린다. 정수가 아니거나 음수이면 -1.
## 실수 연산은 파싱 경계인 여기에만 둔다 (BlockRegistry._to_non_negative_int 와 같은 규칙).
static func _to_non_negative_int(value: Variant) -> int:
    match typeof(value):
        TYPE_INT:
            return value if value >= 0 else -1
        TYPE_FLOAT:
            var number: float = value
            if not is_finite(number) or number < 0.0 or number != floor(number):
                return -1
            return int(number)
    return -1
