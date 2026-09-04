class_name WorldView
extends Node3D

## 복셀 격자를 그린다.
##
## 격자를 읽기만 한다. 여기서 격자를 고치면 표현이 시뮬레이션을 되돌아 밀게 되어
## 결정론이 깨진다.
##
## 속에 묻힌 블록은 그리지 않는다. 이웃 여섯 칸이 모두 단단하면 어차피 보이지 않는다.
## 종류마다 MultiMesh 하나를 써서 수천 칸을 한 번에 낸다.
##
## 생김새는 종류마다 다르다. [BlockMeshes] 가 정한다. 색만으로는 파스텔 열 종을
## 가르기 어렵고, 문은 열린 것과 닫힌 것이 아예 같은 색이다.
##
## **면의 색도 메시가 정한다.** 흙은 윗면이 풀이고 옆면이 흙이다. 그래서
## 여기서 인스턴스에 넘기는 것은 색이 아니라 칸마다의 명암 배수다.

var _grid: VoxelGrid
var _layers: Dictionary[int, MultiMeshInstance3D] = {}
var _last_version: int = -1
var _build_count: int = 0


## 종류별 대표 색.
static func colour_of(block_type: int) -> Color:
    return Palette.of_block(block_type)


func _ready() -> void:
    for block_type in BlockType.COUNT:
        if block_type == BlockType.EMPTY:
            continue
        _layers[block_type] = _make_layer(block_type)


func bind(grid: VoxelGrid) -> void:
    _grid = grid
    _last_version = -1


## 격자가 바뀌었을 때만 다시 만든다.
func sync() -> void:
    if _grid == null or _grid.version() == _last_version:
        return
    rebuild()


func rebuild() -> void:
    if _grid == null:
        return

    var cells: Dictionary[int, Array] = {}
    for block_type in _layers:
        cells[block_type] = []


    for z in VoxelGrid.SIZE_Z:
        for y in VoxelGrid.SIZE_Y:
            for x in VoxelGrid.SIZE_X:
                var pos := Vector3i(x, y, z)
                var block_type := _grid.get_block(pos)
                if not cells.has(block_type):
                    continue
                if not _grid.is_exposed(pos):
                    continue
                cells[block_type].append(pos)

    for block_type in _layers:
        _fill_layer(_layers[block_type], cells[block_type])

    _last_version = _grid.version()
    _build_count += 1


func instance_count(block_type: int) -> int:
    if not _layers.has(block_type):
        return 0
    return _layers[block_type].multimesh.instance_count


func total_instance_count() -> int:
    var total := 0
    for block_type in _layers:
        total += instance_count(block_type)
    return total


## 다시 만든 횟수. 테스트가 불필요한 재구축을 잡는 데 쓴다.
func build_count() -> int:
    return _build_count


func _make_layer(block_type: int) -> MultiMeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    # 칸의 색(인스턴스)과 면의 밝기(정점)가 곱해져 한 면의 색이 된다.
    material.vertex_color_use_as_albedo = true
    # 감는 방향이 어긋나도 안이 비쳐 보이지 않게 한다. 빛은 법선을 따른다.
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var mesh := BlockMeshes.for_block(block_type)
    mesh.surface_set_material(0, material)

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    var node := MultiMeshInstance3D.new()
    node.name = "Layer_" + BlockType.name_of(block_type)
    node.multimesh = multimesh
    add_child(node)
    return node


func _fill_layer(node: MultiMeshInstance3D, cells: Array) -> void:
    var multimesh := node.multimesh
    multimesh.instance_count = cells.size()
    for i in cells.size():
        var cell: Vector3i = cells[i]
        multimesh.set_instance_transform(i, Transform3D(Basis(), SimViewCoords.cell_to_world(cell)))
        # 칸마다 명암을 아주 조금 달리해 넓은 면이 한 덩어리로 보이지 않게 한다.
        # 색은 면이 정하므로(BlockMeshes) 여기서는 배수만 넘긴다.
        var shade := Palette.variation_of(cell)
        multimesh.set_instance_color(i, Color(shade, shade, shade))
