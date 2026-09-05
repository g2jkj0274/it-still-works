class_name VoxelGrid
extends RefCounted

## 고정 크기 복셀 격자. 섬 하나 분량이다.
##
## 청크 스트리밍은 없다. 전체를 하나의 평평한 바이트 배열로 들고 있는다.
## 딕셔너리를 쓰지 않으므로 순회 순서가 항상 같다.
##
## 좌표는 z 를 높이로 쓴다. x, y 가 섬의 바닥면이다.
## Godot 은 y 가 위이므로 표현 레이어가 (x, y, z) → (x, z, y) 로 바꿔 그린다.

const SIZE_X := 64
const SIZE_Y := 64
## 세로. 지하를 파고 그 위에 쌓을 만큼은 있어야 한다.
##
## 16 이던 것을 늘렸다. 그때는 지면이 두 층뿐이라 남는 세로가 뜻이 없었는데,
## 지표를 올려 지하를 파면서 위아래가 다 필요해졌다.
const SIZE_Z := 24
const CELL_COUNT := SIZE_X * SIZE_Y * SIZE_Z

## 높이 방향 단위 벡터.
const UP := Vector3i(0, 0, 1)

## 섬의 바닥층. 부술 수 없다.
const BEDROCK_Z := 0

## 이웃 6방향. 순서가 고정되어 있어야 표면 판정이 항상 같다.
const NEIGHBOURS: Array[Vector3i] = [
    Vector3i(1, 0, 0),
    Vector3i(-1, 0, 0),
    Vector3i(0, 1, 0),
    Vector3i(0, -1, 0),
    Vector3i(0, 0, 1),
    Vector3i(0, 0, -1),
]

## 마지막으로 훑어 간 뒤에 겉모습이 달라졌을 수 있는 칸들.
##
## 표현 레이어가 다시 그릴 곳을 좁히는 데 쓴다. 블록 하나가 바뀌면 그 칸과
## 이웃 여섯 칸의 **드러남**이 달라진다. 그 일곱만 다시 보면 된다.
##
## 이것이 없으면 블록 하나를 놓을 때마다 격자 전체를 훑는다. 육만 칸을 훑는
## 데 백 밀리초가 걸리고, 지하를 채우면 삼백 밀리초가 된다. 한 프레임이
## 십육 밀리초이므로 놓을 때마다 화면이 멎는다.
##
## 격자의 **내용**에 대한 기록이지 그리는 방법에 대한 기록이 아니다.
## 상태 해시에는 들어가지 않는다. 섬을 처음 세울 때처럼 한꺼번에 많이 바뀌면
## 하나씩 고치는 것이 더 비싸므로 통째로 다시 그리라고 알린다.
const DIRTY_LIMIT := 768

var _cells: PackedByteArray = PackedByteArray()
var _version: int = 0
var _dirty: Array[Vector3i] = []
var _dirty_overflow: bool = true

## 최근에 실제로 바뀐 칸들. 각 항목은 [몇 번째 바뀜, 칸, 무엇에서, 무엇으로].
##
## 표현 레이어가 **무슨 일이 일어났는지**를 알아야 할 때 쓴다. 소리가 그렇다.
## 손에 든 것의 총량이 늘고 줄었는지로 부수기와 놓기를 짐작하면, 밭을 거두거나
## 무언가를 만들어도 곡괭이 소리가 난다. 화면과 소리가 다른 것을 말하게 된다.
##
## 오래된 것은 버린다. 소리는 상태가 아니므로 놓쳐도 세상이 어긋나지 않는다.
const CHANGE_MEMORY := 256

var _changes: Array = []


func _init() -> void:
    _cells.resize(CELL_COUNT)
    _cells.fill(BlockType.EMPTY)


static func is_inside(pos: Vector3i) -> bool:
    return (
        pos.x >= 0 and pos.x < SIZE_X
        and pos.y >= 0 and pos.y < SIZE_Y
        and pos.z >= 0 and pos.z < SIZE_Z
    )


static func is_bedrock(pos: Vector3i) -> bool:
    return pos.z <= BEDROCK_Z


static func index_of(pos: Vector3i) -> int:
    return (pos.z * SIZE_Y + pos.y) * SIZE_X + pos.x


## 격자 밖은 빈 칸으로 읽힌다. 통과 가능 여부는 [method is_free] 로 따로 판정한다.
func get_block(pos: Vector3i) -> int:
    if not is_inside(pos):
        return BlockType.EMPTY
    return _cells[index_of(pos)]


## 값이 실제로 바뀌었을 때만 true 를 돌려주고 판을 올린다.
func set_block(pos: Vector3i, type: int) -> bool:
    if not is_inside(pos) or not BlockType.is_valid(type):
        return false

    var index := index_of(pos)
    if _cells[index] == type:
        return false

    var was := _cells[index]
    _cells[index] = type
    _version += 1
    _mark_dirty(pos)

    _changes.append([_version, pos, was, type])
    if _changes.size() > CHANGE_MEMORY:
        _changes = _changes.slice(_changes.size() - CHANGE_MEMORY)
    return true


## 그 칸과 이웃들의 드러남이 달라졌음을 적어 둔다.
func _mark_dirty(pos: Vector3i) -> void:
    if _dirty_overflow:
        return
    if _dirty.size() + NEIGHBOURS.size() + 1 > DIRTY_LIMIT:
        _dirty.clear()
        _dirty_overflow = true
        return

    _dirty.append(pos)
    for offset in NEIGHBOURS:
        var neighbour := pos + offset
        if is_inside(neighbour):
            _dirty.append(neighbour)


## 달라진 칸들을 가져가고 비운다. 적은 차례 그대로다.
func take_dirty() -> Array[Vector3i]:
    var changed := _dirty
    _dirty = []
    _dirty_overflow = false
    return changed


## [param since] 번째 바뀜 뒤에 일어난 일들. [칸, 무엇에서, 무엇으로].
##
## 너무 뒤처져 있으면 기억에 남은 것만 돌려준다. 소리를 몇 번 놓칠 뿐이다.
func changes_since(since: int) -> Array:
    var found: Array = []
    for entry: Array in _changes:
        if int(entry[0]) > since:
            found.append([entry[1], entry[2], entry[3]])
    return found


## 하나씩 고치기보다 통째로 다시 그리는 편이 나은가.
func needs_full_redraw() -> bool:
    return _dirty_overflow


## 아직 아무것도 없는 칸인가. 열린 문은 지나갈 수 있지만 빈 칸은 아니다.
func is_empty_cell(pos: Vector3i) -> bool:
    return is_inside(pos) and get_block(pos) == BlockType.EMPTY


func is_solid(pos: Vector3i) -> bool:
    return BlockType.is_solid(get_block(pos))


## 격자 안이면서 비어 있는 칸. 격자 밖은 자유롭지 않다.
func is_free(pos: Vector3i) -> bool:
    return is_inside(pos) and not is_solid(pos)


## 이웃 한 곳이라도 비어 있으면 표면이다.
## 표현 레이어가 속에 묻힌 블록을 그리지 않도록 걸러내는 데 쓴다.
func is_exposed(pos: Vector3i) -> bool:
    if not is_solid(pos):
        return false
    for offset in NEIGHBOURS:
        if not is_solid(pos + offset):
            return true
    return false


## 그 기둥에서 가장 높은 단단한 칸. 아무것도 없으면 -1.
##
## 표현 레이어가 "이 칸이 지표에서 얼마나 아래인가"를 재는 데 쓴다.
## 격자 자신에 대한 물음이지 그리는 방법에 대한 물음이 아니다.
func height_at(x: int, y: int) -> int:
    for z in range(SIZE_Z - 1, -1, -1):
        if is_solid(Vector3i(x, y, z)):
            return z
    return -1


## 내용이 바뀔 때마다 오르는 값. 표현 레이어가 다시 그릴 시점을 알 때 쓴다.
func version() -> int:
    return _version


## 격자 전체의 다이제스트. 월드 상태 해시에 접혀 들어간다.
func digest() -> String:
    return SimHash.hash_bytes(_cells)


## 읽기 전용 사본. 표현 레이어가 원본을 건드리지 못하게 한다.
func cells() -> PackedByteArray:
    return _cells.duplicate()
