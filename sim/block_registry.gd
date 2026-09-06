class_name BlockRegistry
extends RefCounted

## 블록 속성 표 (헌법 P2).
##
## `data/blocks.json` 을 읽어 블록 id 별 속성 비트·최대 내구도·이름을 평평한 배열에 담는다.
## 시뮬레이션은 이 표에 속성만 묻는다. 블록 이름을 비교하는 코드는 sim 에 두지 않는다 —
## [method name_of] 는 표현 레이어(팔레트 매핑) 전용이다.
##
## 표는 상태가 아니라 규칙이다(DECISIONS 2026-09-06). 상태 해시에 넣지 않고,
## 저장 파일에는 [method digest] 를 적어 다른 표로 불러오는 것을 막는다.
##
## 파싱이 끝나면 Dictionary 는 버린다. 순서 비보장 자료구조를 판단 근거로 남기지 않는다.

## 속성 열. 순서 고정 — 아래 ATTR_* 인덱스와 [method digest] 가 이 순서에 묶여 있다.
const ATTRIBUTES: PackedStringArray = [
    "solid",
    "pushable",
    "conductive",
    "container",
    "emits_sound",
    "gravity",
    "flammable",
    "liquid",
]

const ATTR_SOLID := 0
const ATTR_PUSHABLE := 1
const ATTR_CONDUCTIVE := 2
const ATTR_CONTAINER := 3
const ATTR_EMITS_SOUND := 4
const ATTR_GRAVITY := 5
const ATTR_FLAMMABLE := 6
const ATTR_LIQUID := 7

const DEFAULT_PATH := "res://data/blocks.json"

## 내구도 상한. Chunk 가 셀당 바이트 둘(id · 현재 내구도)을 쓰므로 초기 내구도도 한 바이트에 들어야 한다.
const MAX_DURABILITY := 255

## 블록 수 상한. Chunk 의 셀 id 가 한 바이트라 id 는 0..255 다.
const MAX_BLOCKS := 256

## 속성 외에 각 행이 반드시 가져야 하는 키.
const _SCALAR_KEYS: PackedStringArray = ["id", "name", "durability"]

## id 순 이름. 크기 = 블록 수.
var _names := PackedStringArray()

## id 순 최대 내구도. 0 = 부술 수 없음.
var _max_durability := PackedInt32Array()

## 속성 비트. 인덱스 = id * ATTRIBUTES.size() + 속성 인덱스. 0 또는 1.
var _flags := PackedByteArray()


## 기본 표 `res://data/blocks.json` 을 읽는다. 파일이 없거나 검증에 실패하면 null.
static func load_default() -> BlockRegistry:
    if not FileAccess.file_exists(DEFAULT_PATH):
        return null
    return from_text(FileAccess.get_file_as_string(DEFAULT_PATH))


## JSON 원문에서 표를 만든다. 검증에 하나라도 걸리면 null.
##   - 최상위는 Array, 각 항목은 Dictionary
##   - 각 항목의 키 집합은 id·name·durability + ATTRIBUTES 와 정확히 같다
##   - id·durability 는 0 이상의 정수(JSON 실수는 정수값일 때만 받는다)
##   - durability 는 MAX_DURABILITY 이하, 행 수는 MAX_BLOCKS 이하 (Chunk 의 바이트 폭)
##   - 속성 8개는 bool 만
##   - name 은 비지 않은 문자열
##   - id 는 배열 인덱스와 같다
static func from_text(text: String) -> BlockRegistry:
    var json := JSON.new()
    if json.parse(text) != OK:
        return null
    var data: Variant = json.data
    if typeof(data) != TYPE_ARRAY:
        return null
    var rows: Array = data
    if rows.size() > MAX_BLOCKS:
        return null
    var registry := BlockRegistry.new()
    for index in rows.size():
        var row: Variant = rows[index]
        if typeof(row) != TYPE_DICTIONARY:
            return null
        if not _has_exact_keys(row):
            return null
        if _to_non_negative_int(row["id"]) != index:
            return null
        var durability := _to_non_negative_int(row["durability"])
        if durability < 0 or durability > MAX_DURABILITY:
            return null
        var name: Variant = row["name"]
        if typeof(name) != TYPE_STRING or (name as String).is_empty():
            return null
        for attr in ATTRIBUTES:
            var flag: Variant = row[attr]
            if typeof(flag) != TYPE_BOOL:
                return null
            registry._flags.append(1 if flag else 0)
        registry._names.append(name)
        registry._max_durability.append(durability)
    return registry


## 표에 있는 블록 수. id 는 0 이상 count() 미만이다.
func count() -> int:
    return _names.size()


## 블록 [param id] 가 속성 [param attr] 를 가지는가. 범위 밖 id·모르는 속성은 false.
func has(id: int, attr: StringName) -> bool:
    return has_at(id, ATTRIBUTES.find(String(attr)))


## [method has] 의 인덱스판. 틱 안쪽 핫패스에서 ATTR_* 상수와 함께 쓴다.
func has_at(id: int, attr_index: int) -> bool:
    if id < 0 or id >= _names.size():
        return false
    if attr_index < 0 or attr_index >= ATTRIBUTES.size():
        return false
    return _flags[id * ATTRIBUTES.size() + attr_index] != 0


## 최대 내구도. 초기값이다 — 현재 내구도는 청크 상태에 산다. 범위 밖 id 는 0.
func max_durability(id: int) -> int:
    if id < 0 or id >= _max_durability.size():
        return 0
    return _max_durability[id]


## 부술 수 있는가 (= 최대 내구도가 0 보다 큰가). P2 의 `breakable(내구도)`.
func is_breakable(id: int) -> bool:
    return max_durability(id) > 0


## 블록 이름. 표현 레이어의 팔레트 매핑 전용 — sim 안에서 부르지 않는다. 범위 밖 id 는 "".
func name_of(id: int) -> String:
    if id < 0 or id >= _names.size():
        return ""
    return _names[id]


## 표의 내용 해시. 원문이 아니라 파싱된 배열에서 만들므로 공백·키 순서에 영향받지 않는다.
## 속성 열 순서가 앞에 들어가 열 순서가 바뀌면 값도 바뀐다.
func digest() -> String:
    var fields: Array = []
    fields.append(["attributes", ",".join(ATTRIBUTES)])
    fields.append(["count", count()])
    for id in count():
        fields.append(["%d.name" % id, _names[id]])
        fields.append(["%d.durability" % id, _max_durability[id]])
        for attr_index in ATTRIBUTES.size():
            fields.append(["%d.%s" % [id, ATTRIBUTES[attr_index]], 1 if has_at(id, attr_index) else 0])
    return SimHash.hash_fields(fields)


## 행의 키 집합이 필수 키와 정확히 같은가. 키 수가 같고 필수 키가 전부 있으면
## 남는 키도 없다 — 딕셔너리 순회 없이 판정한다.
static func _has_exact_keys(row: Dictionary) -> bool:
    if row.size() != _SCALAR_KEYS.size() + ATTRIBUTES.size():
        return false
    for key in _SCALAR_KEYS:
        if not row.has(key):
            return false
    for attr in ATTRIBUTES:
        if not row.has(attr):
            return false
    return true


## JSON 의 수를 0 이상의 정수로 되돌린다. 정수가 아니거나 음수이면 -1.
## 실수 연산은 파싱 경계인 여기에만 둔다.
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
