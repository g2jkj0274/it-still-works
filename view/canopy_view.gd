class_name CanopyView
extends Node3D

## 나무 줄기 위에 얹는 잎.
##
## 시뮬레이션에는 잎이 없다. 지형 블록은 네 종뿐이고(스펙 §3.1) 나무는 나무
## 블록을 쌓아 만든 줄기다. **잎은 그 줄기 위에 덧그리는 것이다.** 부수면
## 줄기가 사라지고 잎도 함께 사라진다. 새 블록 종류를 만들지 않는다.
##
## 왜 하는가. 잎이 없으면 나무가 초록 벌판에 꽂힌 갈색 막대로 보인다. 아트
## 방향(스펙 §1)이 겨눈 밝고 경쾌한 톤에서 가장 큰 물건이 나무인데, 그것만
## 형태가 없었다.
##
## **사람이 쌓은 나무 벽에는 잎이 나지 않는다.** 줄기로 치는 것은 땅에서
## 곧게 선 기둥뿐이고, 옆에 나무가 붙어 있으면 벽으로 본다. 그러지 않으면
## 나무로 담을 쌓았을 때 담 위에 숲이 생긴다.

## 줄기로 치는 최소 높이. 이보다 낮으면 벽이나 발판이다.
const MIN_TRUNK := 3

## 잎 덩어리의 크기. 줄기보다 넓게 퍼진다.
const CROWN_WIDTH := 2.4
const CROWN_HEIGHT := 1.5

## 줄기 꼭대기에서 잎 한가운데까지.
const CROWN_LIFT := 0.55

var _grid: VoxelGrid
var _node: MultiMeshInstance3D
var _last_version: int = -1
var _build_count: int = 0
var _crowns: Array[Vector3i] = []


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = Palette.LEAF
    # 잎 덩어리는 면이 많아 뒷면까지 그릴 이유가 없다.
    material.cull_mode = BaseMaterial3D.CULL_BACK

    var mesh := SphereMesh.new()
    mesh.radius = CROWN_WIDTH * 0.5
    mesh.height = CROWN_HEIGHT
    # 각진 세계에 매끈한 공을 두면 겉돈다. 면을 줄여 뭉툭하게 깎는다.
    mesh.radial_segments = 7
    mesh.rings = 3
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    _node = MultiMeshInstance3D.new()
    _node.name = "Crowns"
    _node.multimesh = multimesh
    add_child(_node)


func bind(grid: VoxelGrid) -> void:
    _grid = grid
    _last_version = -1


func sync() -> void:
    if _grid == null or _grid.version() == _last_version:
        return
    rebuild()


func rebuild() -> void:
    if _grid == null:
        return

    _crowns = _find_trunks()
    var multimesh := _node.multimesh
    multimesh.instance_count = _crowns.size()

    for i in _crowns.size():
        var top := SimViewCoords.cell_to_world(_crowns[i])
        multimesh.set_instance_transform(i, Transform3D(
            Basis(Vector3.UP, deg_to_rad(_turn_of(_crowns[i]))),
            top + Vector3.UP * CROWN_LIFT))

    _last_version = _grid.version()
    _build_count += 1


func crown_count() -> int:
    return _node.multimesh.instance_count


func crowns() -> Array[Vector3i]:
    return _crowns.duplicate()


func build_count() -> int:
    return _build_count


## 잎을 얹을 줄기 꼭대기들.
func _find_trunks() -> Array[Vector3i]:
    var tops: Array[Vector3i] = []
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            var top := _trunk_top(x, y)
            if top.z >= 0:
                tops.append(top)
    return tops


## 그 기둥이 나무인가. 나무면 꼭대기 칸, 아니면 z 가 -1.
func _trunk_top(x: int, y: int) -> Vector3i:
    var height := 0
    var top := -1
    for z in range(VoxelGrid.SIZE_Z - 1, -1, -1):
        var cell := Vector3i(x, y, z)
        if _grid.get_block(cell) != BlockType.WOOD:
            if height > 0:
                break
            continue
        if top < 0:
            # 꼭대기 위가 막혀 있으면 지붕이지 나무가 아니다.
            if _grid.is_solid(cell + VoxelGrid.UP):
                return Vector3i(x, y, -1)
            top = z
        height += 1

    if height < MIN_TRUNK or top < 0:
        return Vector3i(x, y, -1)
    if not _stands_alone(x, y, top):
        return Vector3i(x, y, -1)
    return Vector3i(x, y, top)


## 옆에 나무가 붙어 있으면 벽으로 본다. 담 위에 숲이 생기면 안 된다.
func _stands_alone(x: int, y: int, top: int) -> bool:
    for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        if _grid.get_block(Vector3i(x + offset.x, y + offset.y, top)) == BlockType.WOOD:
            return false
    return true


## 자리에서 뽑은 각도. 난수가 아니라 뒤섞기라 실행마다 같다.
static func _turn_of(cell: Vector3i) -> float:
    return float(absi(cell.x * 73856093 ^ cell.y * 19349663) % 360)
