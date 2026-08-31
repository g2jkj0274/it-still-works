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
const SIZE_Z := 16
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

var _cells: PackedByteArray = PackedByteArray()
var _version: int = 0


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

    _cells[index] = type
    _version += 1
    return true


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


## 내용이 바뀔 때마다 오르는 값. 표현 레이어가 다시 그릴 시점을 알 때 쓴다.
func version() -> int:
    return _version


## 격자 전체의 다이제스트. 월드 상태 해시에 접혀 들어간다.
func digest() -> String:
    return SimHash.hash_bytes(_cells)


## 읽기 전용 사본. 표현 레이어가 원본을 건드리지 못하게 한다.
func cells() -> PackedByteArray:
    return _cells.duplicate()
