class_name GroundCover
extends Node3D

## 지면 윗면에 흩뿌린 풀과 꽃과 잔돌.
##
## **꾸밈일 뿐이다.** 시뮬레이션은 이것을 알지 못한다. 부술 수도 없고 길을
## 막지도 않는다. 넓은 초록 면이 종이처럼 보이지 않게 하는 것이 전부다.
##
## 어디에 무엇이 놓이는지는 **칸 좌표에서 뽑는다.** 난수를 쓰지 않으므로
## 실행할 때마다 같은 자리에 같은 것이 난다. 시뮬레이션의 RNG 는 건드리지
## 않는다 — 표현이 난수를 당겨 쓰면 그 순간 결정론이 깨진다.
##
## 모델은 Kenney Nature Kit (CC0). `assets/README.md` 참조.
## **모양만 받고 색은 팔레트가 준다.** 가져온 모델은 제 색을 달고 오는데
## 그대로 두면 톤이 흩어진다. 색을 한 곳에 모아 둔다는 규칙은 여기에도 걸린다.

const MODEL_DIR := "res://assets/kenney_nature_kit/"

## 깔 것들. [파일, 빛깔, 뽑히는 몫]. 풀이 흔하고 버섯이 드물다.
const KINDS: Array = [
    ["grass.glb", Palette.COVER_GRASS, 22],
    ["grass_large.glb", Palette.COVER_GRASS, 12],
    ["grass_leafs.glb", Palette.COVER_LEAF, 14],
    ["plant_bushSmall.glb", Palette.COVER_LEAF, 8],
    ["plant_bush.glb", Palette.COVER_LEAF, 5],
    ["flower_yellowA.glb", Palette.COVER_FLOWER_YELLOW, 6],
    ["flower_purpleA.glb", Palette.COVER_FLOWER_PURPLE, 5],
    ["flower_redA.glb", Palette.COVER_FLOWER_RED, 5],
    ["rock_smallFlatA.glb", Palette.COVER_ROCK, 6],
    ["rock_smallA.glb", Palette.COVER_ROCK, 4],
    ["mushroom_tan.glb", Palette.COVER_MUSHROOM, 2],
    ["mushroom_red.glb", Palette.COVER_FLOWER_RED, 2],
]

## 백 칸 가운데 몇 칸에 무언가가 나는가. 너무 빽빽하면 지면이 안 보인다.
const DENSITY_PERCENT := 14

## 칸 한가운데에서 밀어낼 수 있는 최대 거리. 줄 맞춰 난 것처럼 보이지 않게 한다.
const JITTER := 0.28

## 크기 변주. 1000 을 기준으로 한 배수다.
const SCALE_MIN := 950
const SCALE_MAX := 1450

var _grid: VoxelGrid
var _layers: Array[MultiMeshInstance3D] = []
var _last_version: int = -1
var _build_count: int = 0


func _ready() -> void:
    for entry: Array in KINDS:
        _layers.append(_make_layer(entry[0], entry[1]))


func bind(grid: VoxelGrid) -> void:
    _grid = grid
    _last_version = -1


## 격자가 바뀌었을 때만 다시 뿌린다. 블록을 놓으면 그 자리의 풀은 사라진다.
func sync() -> void:
    if _grid == null or _grid.version() == _last_version:
        return
    rebuild()


func rebuild() -> void:
    if _grid == null:
        return

    var placements: Array[Array] = []
    for i in _layers.size():
        placements.append([])

    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            var cell := _top_of_column(x, y)
            if cell.z < 0:
                continue
            var noise := _noise(cell)
            if noise % 100 >= DENSITY_PERCENT:
                continue
            placements[_pick(noise)].append(_stand(cell, noise))

    for i in _layers.size():
        _fill(_layers[i], placements[i])

    _last_version = _grid.version()
    _build_count += 1


func kind_count() -> int:
    return _layers.size()


func total_instance_count() -> int:
    var total := 0
    for layer in _layers:
        total += layer.multimesh.instance_count
    return total


func build_count() -> int:
    return _build_count


## 그 기둥에서 풀이 날 수 있는 칸. 없으면 z 가 -1 이다.
##
## 흙 윗면이면서 그 위가 비어 있어야 한다. 돌이나 나무 위에는 나지 않는다.
func _top_of_column(x: int, y: int) -> Vector3i:
    for z in range(VoxelGrid.SIZE_Z - 1, -1, -1):
        var cell := Vector3i(x, y, z)
        if not _grid.is_solid(cell):
            continue
        if _grid.get_block(cell) != BlockType.GROUND:
            return Vector3i(x, y, -1)
        if _grid.is_solid(cell + VoxelGrid.UP):
            return Vector3i(x, y, -1)
        return cell
    return Vector3i(x, y, -1)


## 칸 좌표에서 뽑은 값. 난수가 아니라 뒤섞기다.
static func _noise(cell: Vector3i) -> int:
    var mixed := cell.x * 374761393 + cell.y * 668265263 + cell.z * 2147483647
    mixed = (mixed ^ (mixed >> 13)) * 1274126177
    return absi(mixed ^ (mixed >> 16))


## 몫에 따라 무엇이 날지 고른다.
func _pick(noise: int) -> int:
    var total := 0
    for entry: Array in KINDS:
        total += int(entry[2])

    var roll := (noise / 100) % total
    for i in KINDS.size():
        roll -= int(KINDS[i][2])
        if roll < 0:
            return i
    return 0


## 그 칸에 놓일 자리와 방향과 크기.
func _stand(cell: Vector3i, noise: int) -> Transform3D:
    var centre := SimViewCoords.cell_to_world(cell)
    # 칸 윗면에 세운다.
    centre.y += SimViewCoords.CELL_SIZE * 0.5

    var offset_x := float((noise / 10000) % 201 - 100) / 100.0 * JITTER
    var offset_z := float((noise / 3000000) % 201 - 100) / 100.0 * JITTER
    centre += Vector3(offset_x, 0.0, offset_z)

    var turn := float((noise / 700) % 360)
    var scale := float(SCALE_MIN + (noise / 90000) % (SCALE_MAX - SCALE_MIN)) / 1000.0

    var basis := Basis(Vector3.UP, deg_to_rad(turn)).scaled(Vector3.ONE * scale)
    return Transform3D(basis, centre)


func _fill(node: MultiMeshInstance3D, placements: Array) -> void:
    var multimesh := node.multimesh
    multimesh.instance_count = placements.size()
    for i in placements.size():
        multimesh.set_instance_transform(i, placements[i])


func _make_layer(file_name: String, colour: Color) -> MultiMeshInstance3D:
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh_of(file_name)
    multimesh.instance_count = 0

    var node := MultiMeshInstance3D.new()
    node.name = "Cover_" + file_name.get_basename()
    node.multimesh = multimesh
    # 가져온 모델의 제 색을 덮어쓴다. 모양만 받고 색은 팔레트가 준다.
    node.material_override = _tint(colour)
    # 잔풀까지 그림자를 드리우면 톤이 무거워지고 값도 비싸다.
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
    return node


static func _tint(colour: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = colour
    # 잎은 앞뒤가 다 보인다. 뒷면을 자르면 반쪽만 남는다.
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


## glTF 안의 첫 메시. MultiMesh 는 씬이 아니라 메시를 받는다.
static func mesh_of(file_name: String) -> Mesh:
    var scene: PackedScene = load(MODEL_DIR + file_name)
    if scene == null:
        return null

    var root := scene.instantiate()
    var mesh := _first_mesh(root)
    root.free()
    return mesh


static func _first_mesh(node: Node) -> Mesh:
    if node is MeshInstance3D:
        return (node as MeshInstance3D).mesh
    for child in node.get_children():
        var found := _first_mesh(child)
        if found != null:
            return found
    return null
